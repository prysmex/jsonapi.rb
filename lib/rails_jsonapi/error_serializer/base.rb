# frozen_string_literal: true

require 'fast_jsonapi'

module RailsJSONAPI
  module ErrorSerializer

    # A simple error serializer
    class Base
      KEYS = %i[id links status code title detail source meta].freeze

      # @param [Hash|Object|String|StandardError|Array<Hash|Object|String|StandardError>] resource
      # @param [Hash{Symbol => *}] options
      def initialize(resource, options = {})
        @resource = Array.wrap(resource)
        @options = options
      end

      # Override serialization since JSONAPI's errors spec
      # Remap the root key to `errors`
      #
      # @return [Hash]
      def serializable_hash
        errors = @resource.filter_map do |r|
          case r
          when String
            { detail: r }
          when StandardError
            { detail: r.message }
          else
            is_hash = r.is_a?(Hash)

            KEYS.each_with_object({}) do |k, obj|
              value = is_hash ? r[k] : r.try(k)
              obj[k] = value if value
            end.presence
          end
        end

        { errors: }
      end

    end

  end
end