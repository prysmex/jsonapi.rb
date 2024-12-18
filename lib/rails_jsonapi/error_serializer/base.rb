# frozen_string_literal: true

require 'fast_jsonapi'

module RailsJSONAPI
  module ErrorSerializer

    # A simple error serializer
    # This could be a simpler class, since the 'serializable_hash'
    # method is overriden.
    class Base
      include FastJsonapi::ObjectSerializer

      set_id :object_id
      set_type :error

      # define 'attribute's that support Object/Hash
      %i[status source title detail].each do |attr_name|
        attribute attr_name do |object, _params|
          object.try(attr_name) || object.try(:fetch, attr_name, nil)
        end
      end

      # Override serialization since JSONAPI's errors spec
      # Remap the root key to `errors`
      # @return [Hash]
      def serializable_hash
        hash = super[:data] || []
        { errors: hash.map { |error| error[:attributes] } }
      end

    end

  end
end
