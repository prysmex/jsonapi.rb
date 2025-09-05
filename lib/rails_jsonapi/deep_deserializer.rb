# frozen_string_literal: true

module RailsJSONAPI
  class DeepDeserializer
    class FormatError < StandardError; end

    # @param [Hash{String => *}] resource jsonapi payload
    # @param [String|NilClass] lid_key
    def initialize(resource, lid_key)
      @resource = resource
      @lid_key = lid_key
    end

    # @param [Hash{String => *}] resource jsonapi payload
    # @return [Hash{Symbol => *}]
    def deep_deserialize(resource = @resource)
      # allow processing resource
      if block_given?
        new_resource = yield(resource)
        resource = new_resource if new_resource
      end

      data = resource.key?('data') ? resource['data'] : resource

      normalize_resource(data)
      klass_deserializer = RailsJSONAPI.type_to_deserializer_proc.call(required(data, 'type'))

      # Hash{Symbol => *}
      deserialized = klass_deserializer.call(data)

      # handle nested included, supported both at 'data' or 'attributes' level
      if (included = data['included'] || resource['included']).present?
        grouped_by_rel_name = included.group_by do |r|
          matched_rel = data['relationships']&.find do |_k, rel|
            next unless rel['data']

            Array.wrap(rel['data']).any? { |o| o['type'] == required(r, 'type') && o['id'] == required(r, 'id') }
          end
          raise StandardError.new("could not match relationships for  #{r['type']} #{r['id']}") unless matched_rel

          matched_rel&.first
        end

        grouped_by_rel_name.each do |rel_name, group|
          if klass_deserializer.has_one_rel_blocks[rel_name]
            deserialized[:"#{rel_name}_attributes"] = deep_deserialize(group[0])
          elsif klass_deserializer.has_many_rel_blocks[rel_name]
            deserialized[:"#{rel_name}_attributes"] = group.map do |r|
              deep_deserialize(r)
            end
          else
            raise StandardError.new("relationship '#{rel_name}' not defined in #{klass_deserializer.name}")
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

    # raises if key is missing or value is not present
    #
    # @param [Hash] hash
    # @param [String] key
    # @return [*]
    def required(hash, key)
      value = hash[key]
      raise FormatError.new("JSON:API object is missing key '#{key}' or value is empty") unless value.present?

      value
    end

  end
end