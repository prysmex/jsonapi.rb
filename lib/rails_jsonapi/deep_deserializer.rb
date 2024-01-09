module RailsJSONAPI
  class DeepDeserializer

    # @param [Hash{String => *}] resource jsonapi payload
    # @param [String] lid_key
    # @param [String] lid_regex
    def initialize(resource, lid_key, lid_regex)
      @resource = resource
      @lid_key = lid_key
      @lid_regex = lid_regex
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
      
      # remove id if local
      if deserialized[:id]&.to_s&.match(@lid_regex)
        deserialized.delete(:id)
      end
      
      # handle nested included
      if included.present?
        grouped_by_type = included.group_by{|r| r['type'].underscore}

        grouped_by_type.each do |type, group|
          if klass_deserializer.has_one_rel_blocks[type.singularize]
            deserialized["#{type.singularize}_attributes".to_sym] = deep_deserialize(group[0])
          elsif klass_deserializer.has_many_rel_blocks[type]
            deserialized["#{type}_attributes".to_sym] = group.map do |r|
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
      data['attributes'] = data['attributes'].transform_keys{|k| k.underscore } if data['attributes'].present?
      data['relationships'] = data['relationships'].transform_keys{|k| k.underscore } if data['relationships'].present?
      data['attributes'][@lid_key] = data[@lid_key]
    end

  end
end