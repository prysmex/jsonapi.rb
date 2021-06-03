module RailsJSONAPI
  module Deserialization
    extend ActiveSupport::Concern

    class_methods do
        
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
  
      private
    
      def deep_deserialize_jsonapi(resource, lid_key, lid_regex)
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
              deserialized["#{type.singularize}_attributes".to_sym] = deep_deserialize_jsonapi(group[0], lid_key, lid_regex)
            elsif klass_deserializer.has_many_rel_blocks[type]
              deserialized["#{type}_attributes".to_sym] = group.map do |r|
                deep_deserialize_jsonapi(r, lid_key, lid_regex)
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