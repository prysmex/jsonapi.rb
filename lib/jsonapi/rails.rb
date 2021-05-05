require 'jsonapi/error_serializer'
require 'jsonapi/active_model_error_serializer'

# Rails integration
module JSONAPI
  module Rails

    # maps an option key to a method name
    JSONAPI_METHODS_MAPPING = {
      params: :jsonapi_serializer_params,
      meta: :jsonapi_meta,
      # links: :jsonapi_pagination,
      fields: :jsonapi_fields,
      include: :jsonapi_include,
    }

    # Updates the mime types and registers the renderers so they can be used
    # in the controller's render method
    # e.g.
    #  - render jsonapi: ...
    #  - render jsonapi_errors: ...
    # @return [NilClass]
    def self.install!
      return unless defined?(::Rails)

      Mime::Type.register JSONAPI::MEDIA_TYPE, :jsonapi

      # Map the JSON parser to the JSONAPI mime type requests.
      ActionDispatch::Request.parameter_parsers[:jsonapi] = 
          ActionDispatch::Request.parameter_parsers[:json]

      self.register_jsonapi_renderer!
      self.register_jsonapi_errors_renderer!
    end

    # Registers the error renderer
    #
    # If the passed resource is NOT an instance of ActiveModel::Errors
    # JSONAPI::ErrorSerializer is used to serialize, otherwise the
    # serializer is resolved
    # 
    # @return [NilClass]
    def self.register_jsonapi_errors_renderer!
      ActionController::Renderers.add(:jsonapi_errors) do |resource, options|
        self.content_type ||= Mime[:jsonapi]

        many = JSONAPI::Rails.is_collection?(resource, options[:is_collection])
        resource = [resource] unless many

        # render with simple ErrorSerializer
        unless resource.is_a?(ActiveModel::Errors)
          return JSONAPI::ErrorSerializer.new(resource, options)
            .serializable_hash.to_json
        end

        model = resource.instance_variable_get('@base')
        details = resource.details
        messages = resource.messages

        errors = details.each_with_object([]).with_index do | ((key, val), obj), index|
          val.each.with_index do |error_hash, i|
            obj << [ key, error_hash, messages[key][i] ]
          end
        end

        # get serializer class
        model_serializer = if respond_to?(:jsonapi_serializer_class, true)
          jsonapi_serializer_class(model, false)
        else
          JSONAPI::Rails.serializer_class(model, false)
        end

        # render errors
        JSONAPI::ActiveModelErrorSerializer.new(
          errors,
          params: {
            model: model,
            model_serializer: model_serializer
          }
        ).serializable_hash.to_json
      end
    end

    # Adds the default renderer
    #
    # @return [NilClass]
    def self.register_jsonapi_renderer!
      ActionController::Renderers.add(:jsonapi) do |resource, options|
        self.content_type ||= Mime[:jsonapi]

        # JSONAPI_METHODS_MAPPING.to_a[0..1].each do |opt, method_name|
        #   next unless respond_to?(method_name, true)
        #   options[opt] ||= send(method_name, resource)
        # end

        # If it's an empty collection, return it directly.
        many = JSONAPI::Rails.is_collection?(resource, options[:is_collection])
        if many && !resource.any?
          return options.slice(:meta, :links).merge(data: []).to_json
        end

        # JSONAPI_METHODS_MAPPING.to_a[2..-1].each do |opt, method_name|
        #   options[opt] ||= send(method_name) if respond_to?(method_name, true)
        # end

        # get serializer class
        serializer_class = if respond_to?(:jsonapi_serializer_class, true)
          jsonapi_serializer_class(resource, many)
        else
          JSONAPI::Rails.serializer_class(resource, many)
        end

        serializer_class.new(resource, options).serializable_hash.to_json
      end
    end

    # Checks if an object is a collection
    # Stolen from [FastJsonapi::ObjectSerializer], instance method.
    #
    # @param resource [Object] to check
    # @param force_is_collection [NilClass] flag to overwrite
    # @return [TrueClass] upon success
    def self.is_collection?(resource, force_is_collection = nil)
      return force_is_collection unless force_is_collection.nil?

      resource.respond_to?(:size) && !resource.respond_to?(:each_pair)
    end

    # Resolves resource serializer class
    #
    # @param resource [Object] to infer class from
    # @param is_collection [TrueClass] when resource is a collection
    # @return [Class]
    def self.serializer_class(resource, is_collection)
      klass = resource.class
      klass = resource.first.class if is_collection

      "#{klass.name}Serializer".constantize
    end

  end
end
