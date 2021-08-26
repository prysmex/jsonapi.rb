require 'rack/utils'

module RailsJSONAPI
  module Controller

    # @example
    #   class ArticlesController < ActionController::Base

    #     before_action only: [:create, :update], if: -> { json_api_request? } do |ctx|
    #       raw_jsonapi = ctx.params['raw_jsonapi']
    #       key_name = raw_jsonapi['data']['type'].underscore.singularize
          
    #       ctx.params = ctx.params.merge({
    #         "#{key_name}": ctx.class.send(
    #           'deep_deserialize_jsonapi',
    #           raw_jsonapi,
    #           'lid',
    #           ApplicationRecord::LOCAL_ID_REGEX
    #         )
    #       })
    #     end
    
    #     def create
    #       article = Article.new(params[:article])
    
    #       if article.save
    #         render jsonapi: article
    #       else
    #         render jsonapi_errors: article.errors
    #       end
    #     end
    
    #     # ...
    #   end

    def self.included(base)
      base.public_send :include,
          Utils,
          Deserialization
          Errors
    end

    module Utils
      # Checks if the request's content_mime_type matches jsonapi
      #
      # @return [Boolean] true when request contains jsonapi mime
      def json_api_request?
        request
          .try(:content_mime_type)
          .try(:instance_variable_get, '@string') == ::RailsJSONAPI::MEDIA_TYPE
      end
  
      # Extracts and formats 'fields' jsonapi param
      #
      # @example `GET /resource?fields[relationship]=id,created_at`
      #
      # @return [Hash]
      def jsonapi_fields_param
        return {} unless params[:fields].respond_to?(:each_pair)
  
        base_hash = if defined?(ActiveSupport::HashWithIndifferentAccess)
          ActiveSupport::HashWithIndifferentAccess.new
        else
          Hash.new
        end
  
        params[:fields].each_with_object(base_hash) do |(k, v), obj|
          obj[k] = v.to_s.split(',').map(&:strip).compact
        end
      end
  
      # Extracts and formats 'include' jsonapi param
      #
      # @example `GET /resource?include=relationship_1,relationship_2`
      #
      # @return [Array,String]
      def jsonapi_include_param
        _include = case params['include']
          when String
            params['include'].to_s.split(',')
          when Array
            params['include']
          else
            []
          end
  
        _include&.map(&:strip)&.compact
      end
    end

    module Deserialization

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def deep_deserialize_jsonapi(resource, lid_key, lid_regex)
          RailsJSONAPI::DeepDeserializer.new(resource, lid_key, lid_regex)
              .deep_deserialize
        end
      end

    end

    # Helpers to handle some error responses
    #
    # Most of the exceptions are handled in Rails by [ActionDispatch] middleware
    # See: https://api.rubyonrails.org/classes/ActionDispatch/ExceptionWrapper.html
    module Errors
      
      # Callback will register the error handlers
      #
      # @return [Module]
      def self.included(base)
        base.class_eval do
          rescue_from(
            StandardError,
            with: :render_jsonapi_internal_server_error
          ) unless defined?(::Rails) && ::Rails.env.test?
  
          rescue_from(
            ActiveRecord::RecordNotFound,
            with: :render_jsonapi_not_found
          ) if defined?(ActiveRecord::RecordNotFound)
  
          rescue_from(
            ActionController::ParameterMissing,
            with: :render_jsonapi_unprocessable_entity
          ) if defined?(ActionController::ParameterMissing)
        end
      end
  
      private
      
      # Generic error handler callback
      #
      # @param exception [Exception] instance to handle
      # @return [String] JSONAPI error response
      def render_jsonapi_internal_server_error(exception)
        error = { status: '500', title: Rack::Utils::HTTP_STATUS_CODES[500] }
        render jsonapi_errors: [error], status: :internal_server_error
      end
  
      # Not found (404) error handler callback
      #
      # @param exception [Exception] instance to handle
      # @return [String] JSONAPI error response
      def render_jsonapi_not_found(exception)
        error = { status: '404', title: Rack::Utils::HTTP_STATUS_CODES[404] }
        render jsonapi_errors: [error], status: :not_found
      end
  
      # Unprocessable entity (422) error handler callback
      #
      # @param exception [Exception] instance to handle
      # @return [String] JSONAPI error response
      def render_jsonapi_unprocessable_entity(exception)
        source = { pointer: '' }
  
        if !%w{data attributes relationships}.include?(exception.param.to_s)
          source[:pointer] = "/data/attributes/#{exception.param}"
        end
  
        error = {
          status: '422',
          title: Rack::Utils::HTTP_STATUS_CODES[422],
          source: source
        }
  
        render jsonapi_errors: [error], status: :unprocessable_entity
      end

    end

  end
end
