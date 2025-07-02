# frozen_string_literal: true

module RailsJSONAPI
  class DeepDeserializer

    # @param [Hash{String => *}] resource jsonapi payload
    # @param [String|NilClass] lid_key
    def initialize(resource, lid_key)
      @resource = resource
      @lid_key = lid_key
    end

    # @param [Hash{String => *}] resource jsonapi payload
    # @return [Hash{Symbol => *}]
    def deep_deserialize(resource = @resource)
      data = resource.key?('data') ? resource['data'] : resource
      included = resource['included']

      normalize_resource(data)
      klass_deserializer = RailsJSONAPI.type_to_deserializer_proc.call(data['type'])

      # Hash{Symbol => *}
      deserialized = klass_deserializer.call(data)

      # handle nested included
      if included.present?
        grouped_by_type = included.group_by { |r| r['type'].underscore }

        grouped_by_type.each do |type, group|
          if klass_deserializer.has_one_rel_blocks[type.singularize]
            deserialized[:"#{type.singularize}_attributes"] = deep_deserialize(group[0])
          elsif klass_deserializer.has_many_rel_blocks[type]
            deserialized[:"#{type}_attributes"] = group.map do |r|
              deep_deserialize(r)
            end
          end
        end
      end

      deserialized
    end

    private

    # Transforms *attributes* and *relationships* with underscore and sets the local id *lid* into attributes
    #
    # @todo is underscoring necessary? can this be handled by jsonapi-deserializable?
    #
    # @param [Hash{String => *}] data
    # @return [void]
    def normalize_resource(data)
      data['attributes'] = data['attributes'].transform_keys(&:underscore) if data['attributes'].present?
      data['relationships'] = data['relationships'].transform_keys(&:underscore) if data['relationships'].present?
      if @lid_key && (lid = data[@lid_key])
        data['attributes'][@lid_key] = lid
      end
    end

  end
end