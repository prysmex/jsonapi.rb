# frozen_string_literal: true

require 'rails/railtie'

module RailsJSONAPI

  # Call a private method if it exists
  def self.try_private(ctx, method, ...)
    ctx.respond_to?(method, true) ? ctx.send(method, ...) : nil
  end

  module Rails

    # Used to wrap jsonapi request inside a hash with the *raw_jsonapi* key. It is called
    # by the jsonapi ActionDispatch::Request parameter parser
    #
    # @ToDo should only 'data' be moved into '_raw_jsonapi' key?
    PARSER = lambda do |body|
      parsed = ActionDispatch::Request.parameter_parsers[:json].call(body)
      return parsed unless parsed.key?('data') || parsed.key?('included')

      parsed['raw_jsonapi'] = {
        'data' => parsed.delete('data'),
        'included' => parsed.delete('included')
      }.compact!

      parsed
    end

    # Checks if an object is a collection
    # Stolen from [FastJsonapi::ObjectSerializer]
    #
    # @param resource [Object] to check
    # @return [Boolean] true when collection
    def self.collection?(resource)
      resource.respond_to?(:size) && !resource.respond_to?(:each_pair)
    end

    # Resolves resource serializer class
    #
    # @param resource [Object] to infer class from
    # @param is_collection [TrueClass] when resource is a collection
    # @return [Class] serializer
    def self.infer_serializer_from_resource(resource, is_collection)
      klass = if is_collection
          if resource.respond_to?(:model) # SomeModel::ActiveRecord_Relation
            resource.model
          else
            resource.first.class
          end
        else
          resource.class
        end

      RailsJSONAPI.class_to_serializer_proc.call(klass)
    end

    # @param [*] resource
    # @param [Hash{Symbol => *}] options
    # @param [ActionController::API] controller
    # @param [Boolean|NilClass] many
    # @param [Boolean|NilClass] use_hooks
    # @return [Class]
    def self.resource_serializer_class(resource, opts, controller = nil, many = nil, use_hooks = nil)
      many = opts[:is_collection] || collection?(resource) if many.nil?
      use_hooks = !opts[:skip_jsonapi_hooks] if use_hooks.nil?

      # from options
      serializer_class = opts.delete(:serializer_class)
      # from hook
      if !serializer_class && use_hooks && controller.respond_to?(:jsonapi_serializer_class, true)
        serializer_class = controller.send(:jsonapi_serializer_class, resource, many)
      end
      # default
      serializer_class || infer_serializer_from_resource(resource, many)
    end

    #
    # - registers jsonapi mime type
    # - registers jsonapi parameter_parser
    # - registers jsonapi renderer
    # - registers jsonapi_errors renderer
    #
    class Railtie < ::Rails::Railtie

      config.to_prepare do
        RailsJSONAPI.reset_caches!
      end

      # call register methods on the Railtie
      #
      # @todo uncomment MediaTypeFilter middleware
      initializer 'jsonapi-rails.init' do |_app|
        register_mime_type
        register_parameter_parser
        register_jsonapi_renderer
        register_multimodel_jsonapi_renderer
        register_jsonapi_errors_renderer

        # app.middleware.use MediaTypeFilter
      end

      private

      # Registers the jsonapi mime type
      def register_mime_type
        Mime::Type.register RailsJSONAPI::MEDIA_TYPE, :jsonapi
      end

      # Register a parser for jsonapi, see PARSER
      def register_parameter_parser
        ActionDispatch::Request.parameter_parsers[:jsonapi] = PARSER
      end

      # Registers the jsonapi renderer
      #
      # - sets content_type to the registered jsonapi mime type
      # - support jsonapi options hooks
      #   - default_jsonapi_options
      # - serialize
      #   - pass serializer_class option
      #   - call jsonapi_serializer_class hook
      #   - infer based on records
      #
      # @return [NilClass]
      def register_jsonapi_renderer
        ActiveSupport.on_load(:action_controller) do
          # Options that can be passed when calling the renderer
          #
          # @yieldparam [Object,Array<Object>] resource
          # @yieldparam [Hash] options
          # @option options [Boolean] :is_collection
          # @option options [Class] :serializer_class
          # @option options [Boolean] :skip_jsonapi_hooks
          # *any other options for the serializer class
          ActionController::Renderers.add(:jsonapi) do |resource, opts|
            self.content_type = Mime[:jsonapi] if RailsJSONAPI.force_content_type || !content_type

            many = opts[:is_collection] || RailsJSONAPI::Rails.collection?(resource)
            # preload data
            data = many ? resource.to_a : resource
            is_empty_collection = many && data.empty? # check if empty

            use_hooks = !opts[:skip_jsonapi_hooks]

            # call hooks
            if use_hooks
              # default_jsonapi_options
              if (default_opts = RailsJSONAPI.try_private(self, :default_jsonapi_options, resource, opts))
                opts = default_opts.merge(opts)
              end

              unless is_empty_collection # do not call
                # hook to handle fields param
                RailsJSONAPI.try_private(self, :handle_jsonapi_fields_param, resource, opts) if jsonapi_fields_param

                # hook to handle include param
                RailsJSONAPI.try_private(self, :handle_jsonapi_include_param, resource, opts) if jsonapi_include_param
              end
            end

            # If it's an empty collection, return it
            return Oj.dump(opts.slice(:meta, :links).merge(data:), mode: :compat) if is_empty_collection

            # get serializer class
            value = RailsJSONAPI::Rails.resource_serializer_class(resource, opts, self, many, use_hooks)
              .new(data, opts)
              .serializable_hash

            Oj.dump(value, mode: :compat)
          end
        end
      end

      # Registers the multi jsonapi renderer
      #
      def register_multimodel_jsonapi_renderer
        ActiveSupport.on_load(:action_controller) do
          # Options that can be passed when calling the renderer
          #
          # @yieldparam [Object,Array<Object>] resource
          # @yieldparam [Hash] options
          # @option options [Hash<Class>] :multimodel_options
          #   - serializer_class_proc [Class,Proc]
          #   - klass, each class may have the following keys:
          #       - :sort_type [Symbol]
          #       - :sort_id_attr [Symbol]
          #       - :options
          # *any other options for the serializer class
          ActionController::Renderers.add(:multimodel_jsonapi) do |resource, opts|
            self.content_type = Mime[:jsonapi] if RailsJSONAPI.force_content_type || !content_type

            multimodel_options = opts.delete(:multimodel_options) || {}

            # root defaults
            serializer = (
              multimodel_options[:serializer_class_proc] ||
              RailsJSONAPI.class_to_multimodel_serializer_proc
            ).call(record.class)

            payload = {data: [], included: []}

            # group so we can serialize them together by type
            grouped_records = resource.group_by(&:class)

            # serialize data and add it to the payload
            grouped_records.each do |klass, records|
              # by klass defaults
              klass_options = multimodel_options[klass] ||= {}
              klass_options[:sort_type] ||= klass.name.underscore
              klass_options[:sort_id_attr] ||= :id
              klass_options[:options] ||= {}

              serialized_data = serializer
                .new(records, klass_options[:options])
                .serializable_hash

              payload[:data].concat(serialized_data[:data]) if serialized_data[:data]
              payload[:included].concat(serialized_data[:included]) if serialized_data[:included]
            end

            # sort the data based on original resource
            cache = {}
            payload[:data].sort! do |obj|
              obj_type = cache[obj[:type]] ||= obj[:type].to_s.underscore.singularize
              obj_id = obj[:id].to_s

              resource.index do |r|
                sort_type = multimodel_options.dig(r.class, :sort_type)
                sort_id_attr = multimodel_options.dig(r.class, :sort_id_attr)

                r.public_send(sort_id_attr).to_s == obj_id && sort_type.to_s == obj_type
              end
            end

            Oj.dump(payload, mode: :compat)
          end
        end
      end

      # Registers the error renderer
      #
      # - sets content_type to the registered jsonapi mime type
      # - If passed resource is an instance of `ActiveModel::Errors`
      #   - `RailsJSONAPI::ErrorSerializer::ActiveModel` is used to serialize errors
      #   - record serializer is required
      #     - record_serializer option
      #     - jsonapi_serializer_class hook
      #     - jsonapi_serializer_class hook
      # - otherwise
      #   - `ErrorSerializer::Base` is used to serialize errors
      #
      # @return [NilClass]
      def register_jsonapi_errors_renderer
        ActiveSupport.on_load(:action_controller) do
          # Options that can be passed when calling the renderer
          #
          # - is_collection
          ActionController::Renderers.add(:jsonapi_errors) do |resource, opts|
            self.content_type = Mime[:jsonapi] if RailsJSONAPI.force_content_type || !content_type

            use_hooks = !opts[:skip_jsonapi_hooks]
            many = opts[:is_collection] || RailsJSONAPI::Rails.collection?(resource)

            # call hooks
            if use_hooks
              # default_jsonapi_options
              if (default_opts = RailsJSONAPI.try_private(self, :default_jsonapi_options, resource, opts)) # rubocop:disable Style/SoleNestedConditional
                opts = default_opts.merge(opts)
              end
            end

            # get serializer class
            serializer_class = opts.delete(:errors_serializer_class)
            if !serializer_class && use_hooks && respond_to?(:jsonapi_errors_serializer_class, true)
              serializer_class = jsonapi_errors_serializer_class(resource, many)
            end
            serializer_class ||= RailsJSONAPI.class_to_errors_serializer_proc.call(resource.class)

            value = serializer_class.new(resource, opts).serializable_hash
            Oj.dump(value, mode: :compat)
          end
        end
      end

    end

  end
end