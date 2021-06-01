module RailsJSONAPI
  module Deserialization
    extend ActiveSupport::Concern

    class_methods do
        
      #   @example
      #     class ArticlesController < ActionController::Base

      #       json_api_deserialize({
      #         key: (->(h) { h['data']['type'].underscore.singularize }),
      #         lid_regex: ApplicationRecord::LOCAL_ID_REGEX,
      #         only: [:create, :update],
      #         if: -> { json_api_request? }
      #       })
        
      #       def create
      #         article = Article.new(params[:article])
        
      #         if article.save
      #           render jsonapi: article
      #         else
      #           render jsonapi_errors: article.errors
      #         end
      #       end
        
      #       # ...
      #     end
  
      def json_api_deserialize(callback_method: 'before_action', key: , lid_key: 'lid', lid_regex: 'local', **callback_options)
        unless [String, Symbol, Proc].include?(key.class)
          raise TypeError.new("key must be String, Symbol or Proc, got #{key.class}")
        end

        public_send(callback_method, callback_options) do |ctx|
          raw_jsonapi = ctx.params['raw_jsonapi']
          key = key.is_a?(Proc) ? key.call(raw_jsonapi) : key
          
          ctx.params = ctx.params.merge({
            "#{key}": self.class.send('deep_deserialize', raw_jsonapi, lid_key, lid_regex)
          })
        end
        
      end
  
      private
    
      def deep_deserialize(resource, lid_key, lid_regex)
        data = resource.key?('data') ? resource['data'] : resource
        included = resource['included']

        data = normalize_resource(data, lid_key)
        klass_deserializer = deserializer_for(data)
        deserialized = klass_deserializer.call(data)
        
        # remove id if local
        if deserialized[:id]&.to_s&.match(lid_regex)
          deserialized.delete(:id)
        end
        
        # handle nested included
        if included.present?
          grouped_by_type = included.group_by{|r| r['type'].underscore}
  
          grouped_by_type.each do |type, group|
            if klass_deserializer.has_one_rel_blocks[type.singularize]
              deserialized["#{type.singularize}_attributes".to_sym] = deep_deserialize(group[0], lid_key, lid_regex)
            elsif klass_deserializer.has_many_rel_blocks[type]
              deserialized["#{type}_attributes".to_sym] = group.map do |r|
                deep_deserialize(r, lid_key, lid_regex)
              end
            end
          end
        end
    
        deserialized
      end
    
      def normalize_resource(data, lid_key)
        data['attributes'] = data['attributes'].transform_keys{|k| k.underscore } if data['attributes'].present?
        data['relationships'] = data['relationships'].transform_keys{|k| k.underscore } if data['relationships'].present?
        data['attributes'][lid_key] = data[lid_key]
        data
      end
    
      def deserializer_for(data)
        type = data['type'].underscore
        "Deserializable#{type.classify}".constantize
      end
    end

  end
end