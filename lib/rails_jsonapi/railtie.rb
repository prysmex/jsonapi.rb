
require 'rails/railtie'

module RailsJSONAPI
  module Rails

    #ToDo should only 'data' be moved into '_raw_jsonapi' key?
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
    # Stolen from [FastJsonapi::ObjectSerializer], instance method.
    #
    # @param resource [Object] to check
    # @return [TrueClass] upon success
    def self.is_collection?(resource)
      resource.respond_to?(:size) && !resource.respond_to?(:each_pair)
    end

    # Resolves resource serializer class
    #
    # @param resource [Object] to infer class from
    # @param is_collection [TrueClass] when resource is a collection
    # @return [Class]
    def self.infer_serializer_class(resource, is_collection)
      klass = if is_collection
          if resource.respond_to?(:model) #SomeModel::ActiveRecord_Relation
            resource.model
          else
            resource.first.class
          end
        else
          resource.class
        end

      "#{klass.name}Serializer".constantize
    end

    class Railtie < ::Rails::Railtie

      # maps an option key to a method name
      JSONAPI_METHODS_MAPPING = {
        params: :jsonapi_serializer_params,
        meta: :jsonapi_meta,
        links: :jsonapi_links,
        fields: :jsonapi_fields,
        include: :jsonapi_include,
      }

      initializer 'jsonapi-rails.init' do |app|
        register_mime_type
        register_parameter_parser
        register_jsonapi_renderer
        register_jsonapi_errors_renderer

        # app.middleware.use MediaTypeFilter ToDo
      end

      private

      def register_mime_type
        Mime::Type.register RailsJSONAPI::MEDIA_TYPE, :jsonapi
      end
      
      # Map the JSON parser to the RailsJSONAPI mime type requests.
      def register_parameter_parser
        ActionDispatch::Request.parameter_parsers[:jsonapi] = PARSER
      end

      # Adds the default renderer
      #
      # @return [NilClass]
      def register_jsonapi_renderer
        ActiveSupport.on_load(:action_controller) do
          ActionController::Renderers.add(:jsonapi) do |resource, options|
            self.content_type ||= Mime[:jsonapi]
  
            # call options hooks
            unless options[:skip_jsonapi_methods]

              # call default options hook
              if respond_to?(:default_jsonapi_options, true)
                options = (send(:default_jsonapi_options, resource, options) || {}).merge(options)
              end

              # call specific option hooks
              JSONAPI_METHODS_MAPPING.each do |json_api_key, method_name|
                next if !respond_to?(method_name, true) || (options.key?(json_api_key) && !options[:force_jsonapi_methods])
                options[json_api_key] = send(method_name, resource, options[method_name])
              end
            end
  
            # If it's an empty collection, return it directly.
            many = options[:is_collection] || RailsJSONAPI::Rails.is_collection?(resource)
            if many && !resource.any?
              return options.slice(:meta, :links).merge(data: []).to_json
            end
  
            # get serializer class
            serializer_class = if options.key?(:serializer_class)
                options.delete(:serializer_class)
              elsif respond_to?(:jsonapi_serializer_class, true)
                jsonapi_serializer_class(resource, many)
              else
                RailsJSONAPI::Rails.infer_serializer_class(resource, many)
              end
              
            serializer_class.new(resource, options).serializable_hash.to_json
          end
        end
      end

      # Registers the error renderer
      #
      # If the passed resource is NOT an instance of ActiveModel::Errors
      # RailsJSONAPI::ErrorSerializer is used to serialize, otherwise the
      # serializer is resolved
      # 
      # @return [NilClass]
      def register_jsonapi_errors_renderer
        ActiveSupport.on_load(:action_controller) do
          ActionController::Renderers.add(:jsonapi_errors) do |resource, options|
            self.content_type ||= Mime[:jsonapi]
  
            many = options[:is_collection] || RailsJSONAPI::Rails.is_collection?(resource)
            if resource.is_a?(ActiveModel::Errors)
              # render with ActiveModelErrorSerializer
              model = resource.instance_variable_get('@base')
              details = resource.details
              messages = resource.messages
  
              errors = details.each_with_object([]).with_index do | ((key, val), obj), index|
                val.each.with_index do |error_hash, i|
                  obj << [ key, error_hash, messages[key][i] ]
                end
              end
  
              # get serializer class
              model_serializer = if options.key?(:model_serializer)
                  options.delete(:model_serializer)
                elsif respond_to?(:jsonapi_serializer_class, true)
                  jsonapi_serializer_class(model, many)
                else
                  "#{model.class.name}Serializer".constantize
                end
  
              RailsJSONAPI::ActiveModelErrorSerializer.new(
                errors,
                params: {
                  model: model,
                  model_serializer: model_serializer
                }
              ).serializable_hash.to_json
            else
              # render with simple ErrorSerializer
              resource = [resource] unless many
              RailsJSONAPI::ErrorSerializer.new(resource, options)
                .serializable_hash
                .to_json
            end
  
          end
        end
      end
      
    end

  end
end