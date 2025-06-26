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
      %i[id links status code title detail source meta].each do |name|
        attribute name do |object, _params|
          object.try(name) || object.try(:fetch, name, nil)
        end
      end

      # Override serialization since JSONAPI's errors spec
      # Remap the root key to `errors`
      # @return [Hash]
      def serializable_hash
        super.then do |hash|
          errors = (hash[:data] || []).map { |error| error[:attributes].select { |_k, v| v.present? } }

          {errors:}
        end
      end

    end

  end
end
