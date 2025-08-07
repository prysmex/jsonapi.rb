# frozen_string_literal: true

require 'fast_jsonapi'

module RailsJSONAPI
  module ErrorSerializer

    # A simple error serializer
    class Base
      KEYS = %i[id links status code title detail source meta].freeze

      # @param [Hash|Object|Array<Hash|Object>] resource
      # @param [Hash{Symbol => *}] options
      def initialize(resource, options = {})
        @resource = Array.wrap(resource)
        @options = options
      end

      # Override serialization since JSONAPI's errors spec
      # Remap the root key to `errors`
      # @return [Hash]
      def serializable_hash
        errors = @resource.filter_map do |r|
          is_hash = r.is_a?(Hash)

          error = KEYS.each_with_object({}) do |k, obj|
            val = is_hash ? r[k] : r.try(k)
            next unless val

            obj[k] = val
          end
          next if error.empty?

          error
        end

        { errors: }
      end

    end

  end
end
