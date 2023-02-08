require 'rails/railtie'

module RailsJSONAPI
  module Rails

    # Used to wrap jsonapi request inside a hash with the *raw_jsonapi* key. It is called
    # by the jsonapi ActionDispatch::Request parameter parser
    #
    # @ToDo should only 'data' be moved into '_raw_jsonapi' key?
    PARSER = lambda do |body|
      parsed = ActionDispatch::Request.parameter_parsers[:json].call(body)
      parsed.merge({
        'raw_jsonapi' => {
          'data' => parsed.delete('data'),
          'included' => parsed.delete('included')
        }.compact
      })
    end

    # Checks if an object is a collection
    # Stolen from [FastJsonapi::ObjectSerializer]
    #
    # @param resource [Object] to check
    # @return [Boolean] true when collection
    def self.is_collection?(resource)
      resource.respond_to?(:size) && !resource.respond_to?(:each_pair)
    end

    # Resolves resource serializer class
    #
    # @param resource [Object] to infer class from
    # @param is_collection [TrueClass] when resource is a collection
    # @return [Class] serializer
    def self.infer_serializer_from_resource(resource, is_collection)
      klass = if is_collection
          if resource.respond_to?(:model) #SomeModel::ActiveRecord_Relation
            resource.model
          else
            resource.first.class
          end
        else
          resource.class
        end

      RailsJSONAPI.class_to_serializer_proc.call(klass)
    end

    #
    # - registers jsonapi mime type
    # - registers jsonapi parameter_parser
    # - registers jsonapi renderer
    # - registers jsonapi_errors renderer
    #
    class Railtie < ::Rails::Railtie

      # maps an option key to a method (hook) name
      JSONAPI_HOOKS_MAPPING = {
        params: :jsonapi_serializer_params,
        meta: :jsonapi_meta,
        links: :jsonapi_links,
        fields: :jsonapi_fields,
        include: :jsonapi_include,
      }

      # call register methods on the Railtie
      #
      # @todo uncomment MediaTypeFilter middleware
      initializer 'jsonapi-rails.init' do |app|
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
      #   - see JSONAPI_HOOKS_MAPPING
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
          # @option options [Boolean] :force_jsonapi_hooks
          # *any other options for the serializer class
          ActionController::Renderers.add(:jsonapi) do |resource, options|

            self.content_type ||= Mime[:jsonapi]
  
            # call hooks
            unless options[:skip_jsonapi_hooks]
              # default_jsonapi_options
              if respond_to?(:default_jsonapi_options, true)
                options = (send(:default_jsonapi_options, resource, options) || {}).merge(options)
              end

              # call specific option hooks (JSONAPI_HOOKS_MAPPING) if defined
              # if passed *options* already has the key, the hook will not be called unless *force_jsonapi_hooks* is truthy
              JSONAPI_HOOKS_MAPPING.each do |json_api_key, hook_name|
                next if !respond_to?(hook_name, true) || (options.key?(json_api_key) && !options[:force_jsonapi_hooks])
                options[json_api_key] = send(hook_name, resource, options[hook_name])
              end
            end
  
            # If it's an empty collection, return it
            many = options[:is_collection] || RailsJSONAPI::Rails.is_collection?(resource)

            # preload data
            data = many ? resource.to_a : resource

            # return early
            if many && data.empty?
              return options.slice(:meta, :links).merge(data: []).to_json
            end

            # get serializer class
            serializer_class = if options.key?(:serializer_class)
              options.delete(:serializer_class)
            elsif respond_to?(:jsonapi_serializer_class, true)
              jsonapi_serializer_class(resource, many)
            else
              RailsJSONAPI::Rails.infer_serializer_from_resource(resource, many)
            end

            serializer_class.new(data, options).serializable_hash.to_json
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
          ActionController::Renderers.add(:multimodel_jsonapi) do |resource, options|

            multimodel_options = options.delete(:multimodel_options) || {}

            # root defaults
            multimodel_options[:serializer_class_proc] ||= ->(klass_name){ "#{klass_name}Serializer" }

            payload = {data: [], included: []}
          
            # group so we can serialize them together by type
            grouped_records = resource.group_by { |r| r.class.name }
            
            # serialize data and add it to the payload
            grouped_records.each do |klass_name, records|

              # by klass defaults
              klass_options = multimodel_options[klass_name.safe_constantize] ||= {}
              klass_options[:sort_type] ||= klass_name.underscore
              klass_options[:sort_id_attr] ||= :id
              klass_options[:options] ||= {}

              serialized_data = multimodel_options[:serializer_class_proc].call(klass_name)
                  .safe_constantize.new(records, klass_options[:options])
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
            
            send_data payload.to_json, type: Mime[:jsonapi]
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
          ActionController::Renderers.add(:jsonapi_errors) do |resource, options|

            self.content_type ||= Mime[:jsonapi]

            many = options[:is_collection] || RailsJSONAPI::Rails.is_collection?(resource)
            
            if resource.is_a?(ActiveModel::Errors)
              record = resource.instance_variable_get('@base')
              details = resource.details
              messages = resource.messages
  
              # build array of arrays, one for each validation error
              # [
              #   [:email, {:error=>:blank}, "no puede estar en blanco"],
              #   [:email, {:error=>:should_not_be_empty}, "Correo electrónico o teléfono deben de estar presentes"]
              # ]
              errors = details.each_with_object([]) do |(attribute, errors), obj|
                errors.each.with_index do |error_hash, i|
                  obj << [ attribute, error_hash, messages[attribute][i] ]
                end
              end
  
              # get serializer for the record
              record_serializer = if options.key?(:record_serializer)
                  options.delete(:record_serializer)
                elsif respond_to?(:jsonapi_serializer_class, true)
                  jsonapi_serializer_class(record, many)
                else
                  RailsJSONAPI.class_to_serializer_proc.call(record.class)
                end
              
              # add params to options
              options[:params] ||= {}
              options[:params].merge!({
                record: record,
                record_serializer: record_serializer
              })
  
              RailsJSONAPI::ErrorSerializer::ActiveModel.new(errors, options)
                .serializable_hash
                .to_json
            else
              resource = [resource] unless many
              RailsJSONAPI::ErrorSerializer::Base.new(resource, options)
                .serializable_hash
                .to_json
            end
  
          end
        end
      end
      
    end

  end
end