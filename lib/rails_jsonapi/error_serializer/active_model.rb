# frozen_string_literal: true

module RailsJSONAPI
  module ErrorSerializer
    # Serializer that handles ActiveModel::Errors objects
    #
    # first argument of +attribute+ is:
    # [
    #   [:email, {:error=>:blank}, "no puede estar en blanco"]
    #   [...]
    # ]
    #
    # @note requires record to respond to +lid_id+
    #
    class ActiveModel < Base
      STATUS = 422

      set_id :object_id
      set_type :error

      attribute :status do
        STATUS.to_s
      end

      attribute :title do
        Rack::Utils::HTTP_STATUS_CODES[STATUS]
      end

      attribute :code do |object, _|
        object[1][:error] || :invalid
      end

      attribute :detail do |object, params|
        error_key, _error_hash, error_msg = object
        errors_object = params[:record].errors

        error_key_s = error_key.to_s
        if error_key_s.include?('.')
          # contains a '.' (nested attributes)
          # has_many :recognitions, dependent: :destroy, index_errors: true
          path = error_key_s.split('.')
          attribute = path.pop

          if (record = get_record_from_errors_path(params[:record], path))
            model_i18n = I18n.t("activerecord.models.#{record.class.name.underscore}.one")
            id = record.id || record.try(:lid_id)
            error_msgs = record.errors.full_message(attribute, error_msg)

            "(#{model_i18n} #{id}) #{error_msgs}"
          else
            errors_object.full_message(error_key, error_msg)
          end
        else
          errors_object.full_message(error_key, error_msg)
        end
      end

      attribute :source do |object, params|
        error_key = object[0]
        record_serializer = params[:record_serializer]
        attrs = (record_serializer.attributes_to_serialize || {}).keys
        rels = (record_serializer.relationships_to_serialize || {}).keys

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
end
