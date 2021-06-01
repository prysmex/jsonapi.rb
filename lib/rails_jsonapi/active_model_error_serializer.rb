require 'rails_jsonapi/error_serializer'

module RailsJSONAPI
  # Serializer that handles ActiveModel::Errors objects
  class ActiveModelErrorSerializer < ErrorSerializer
    set_id :object_id
    set_type :error

    attribute :status do
      '422'
    end

    attribute :title do
      Rack::Utils::HTTP_STATUS_CODES[422]
    end

    attribute :code do |object|
      _, error_hash, _ = object

      code = error_hash[:error] || :invalid
      # `parameterize` separator arguments are different on Rails 4 vs 5...
      code.to_s.delete("''").parameterize.tr('-', '_')
    end

    attribute :detail do |object, params|
      error_key, _, error_msg = object
      errors_object = params[:model].errors

      error_key_s = error_key.to_s
      if !error_key_s.match(/\./)
        errors_object.full_message(error_key, error_msg)
      else
        # contains a '.' (nested attributes)
        path = error_key_s.split('.')
        attribute = path.pop
        record = get_record_from_errors_path(params[:model], path)
        if record
           "(#{I18n.t("activerecord.models.#{record.class.name.underscore}.one")} #{(record.id || record.lid_id)}) " + record.errors.full_message(attribute, error_msg)
        else
          errors_object.full_message(error_key, error_msg)
        end
      end
    end

    attribute :source do |object, params|
      error_key, _, _ = object
      model_serializer = params[:model_serializer]
      attrs = (model_serializer.attributes_to_serialize || {}).keys
      rels = (model_serializer.relationships_to_serialize || {}).keys

      if attrs.include?(error_key)
        { pointer: "/data/attributes/#{error_key}" }
      elsif rels.include?(error_key)
        { pointer: "/data/relationships/#{error_key}" }
      else
        { pointer: '' }
      end
    end

    def self.get_record_from_errors_path(instance, path)
      current = path.shift
      position_string = current.match(/\[(\d)\]\z/)
      return if position_string.nil?
    
      method = current.sub(position_string[0], '')
      instance_at_index = instance.public_send(method)&.public_send('[]', position_string[0][1].to_i)
      return if instance_at_index.nil?
      if path.empty?
        instance_at_index
      else
        get_record_from_errors_path(instance_at_index, path)
      end
    end

  end
end
