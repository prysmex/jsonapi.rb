# frozen_string_literal: true

require 'rack/utils'

module RailsJSONAPI
  module Controller

    # @example
    #   class ArticlesController < ActionController::Base

    #     before_action only: [:create, :update], if: -> { jsonapi_request_content_type? } do |ctx|
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
      base.include Utils, Deserialization # , Errors
    end

    module Utils
      # Returns true if the incoming request body is JSON:API
      #
      # @return [Boolean]
      def jsonapi_request_content_type?
        request.try(:content_mime_type) == Mime[:jsonapi]
      end

      # Extracts and formats 'fields' jsonapi param
      #
      # @example `GET /resource?fields[model]=id,created_at`
      #
      # @return [NilClass|Hash{String => Array<String>}]
      def jsonapi_fields_param
        return unless params[:fields].respond_to?(:each_pair)

        params[:fields].as_json.transform_values do |v|
          v.is_a?(String) ? v.split(',') : v
        end
      end

      # Extracts and formats 'include' jsonapi param
      #
      # @example `GET /resource?include=relationship_1,relationship_2`
      #
      # @return [NilClass|Array<String>]
      def jsonapi_include_param
        case (include = params['include'])
        when String
          include.split(',')
        when Array
          include
        end
      end
    end

    module Deserialization

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        # @param resource [ActionController::Parameters]
        # @param lid_key [String|NilClass]
        # @return [Hash{Symbol => *}]
        def deep_deserialize_jsonapi(resource, *, **, &)
          resource = resource.as_json if resource.is_a?(ActionController::Parameters)
          RailsJSONAPI::DeepDeserializer.new(resource, *, **)
            .deep_deserialize(&)
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
          unless defined?(::Rails) && ::Rails.env.test?
            rescue_from(
              StandardError,
              with: :render_jsonapi_internal_server_error
            )
          end

          if defined?(ActiveRecord::RecordNotFound)
            rescue_from(
              ActiveRecord::RecordNotFound,
              with: :render_jsonapi_not_found
            )
          end

          if defined?(ActionController::ParameterMissing)
            rescue_from(
              ActionController::ParameterMissing,
              with: :render_jsonapi_unprocessable_entity
            )
          end
        end
      end

      private

      # Generic error handler callback
      #
      # @param exception [Exception] instance to handle
      # @return [String] JSONAPI error response
      def render_jsonapi_internal_server_error(_exception)
        error = { status: '500', title: Rack::Utils::HTTP_STATUS_CODES[500] }
        render jsonapi_errors: [error], status: :internal_server_error
      end

      # Not found (404) error handler callback
      #
      # @param exception [Exception] instance to handle
      # @return [String] JSONAPI error response
      def render_jsonapi_not_found(_exception)
        error = { status: '404', title: Rack::Utils::HTTP_STATUS_CODES[404] }
        render jsonapi_errors: [error], status: :not_found
      end

      # Unprocessable entity (422) error handler callback
      #
      # @param exception [Exception] instance to handle
      # @return [String] JSONAPI error response
      def render_jsonapi_unprocessable_entity(exception)
        source = { pointer: '' }

        unless %w[data attributes relationships].include?(exception.param.to_s)
          source[:pointer] = "/data/attributes/#{exception.param}"
        end

        error = {
          status: '422',
          title: Rack::Utils::HTTP_STATUS_CODES[422],
          source:
        }

        render jsonapi_errors: [error], status: :unprocessable_entity
      end

    end

  end
end
