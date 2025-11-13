# frozen_string_literal: true

module RailsJSONAPI
  module ErrorSerializer
    # Serializer that handles ActiveModel::Errors objects
    class ActiveModel < RailsJSONAPI::ErrorSerializer::Base

      STATUS = 422

      # @param [ActiveModel::Errors] resource
      # @param [Hash] options
      def initialize(resource, options = {})
        unless resource.is_a?(::ActiveModel::Errors)
          raise TypeError.new("expected ActiveModel::Errors, got #{resource.class.name}")
        end

        @resource = resource
        @options = options
        @record = @resource.instance_variable_get(:@base)
      end

      # [
      #   {
      #     "status": "422",
      #     "code": "Clasificación no puede estar en blanco",
      #     "title": "Unprocessable Content",
      #     "detail": " Clasificación no puede estar en blanco",
      #     "source": {
      #       "pointer": ""
      #     }
      #   }
      # ]
      #
      # @return [Array<Hash>]
      def serializable_hash
        # set attributes and relationships
        serializer_klass = @options&.dig(:params, :record_serializer) ||
                           RailsJSONAPI::Rails.resource_serializer_class(@record, @options)
        if serializer_klass
          @attrs ||= serializer_klass.attributes_to_serialize.keys.map { |k| k.to_s.underscore.to_sym } || []
          @rels ||= serializer_klass.relationships_to_serialize.keys.map { |k| k.to_s.underscore.to_sym } || []
        end

        details = @resource.details
        messages = @resource.messages

        errors = details.each_with_object([]) do |(attribute, errs), obj|
          errs.each.with_index do |error_hash, i|
            # build array of arrays, one for each validation error
            # [
            #   [:email, {:error=>:blank}, "no puede estar en blanco"],
            #   [:email, {:error=>:should_not_be_empty}, "Correo electrónico o teléfono deben de estar presentes"]
            # ]
            error_item = [attribute, error_hash, messages.dig(attribute, i)]

            # execute all possible methods if they are defined
            hash = KEYS.each_with_object({}) do |k, obj|
              val = send(k, error_item) if respond_to?(k, true)
              next unless val

              obj[k] = val
            end

            obj << hash if hash.present?
          end
        end

        { errors: }
      end

      private

      # @return [Integer]
      def status_or_default
        @options[:status] || STATUS
      end

      # @param [Array] error_item
      # @return [String]
      def status(_error_item)
        status_or_default.to_s
      end

      # @param [Array] error_item
      # @return [String]
      def code(error_item)
        (error_item.dig(1, :error) || :invalid).to_s
      end

      # @param [Array] error_item
      # @return [String]
      def title(_error_item)
        Rack::Utils::HTTP_STATUS_CODES[status_or_default]
      end

      # @param [Array] error_item
      # @return [String]
      def detail(error_item)
        error_key, _error_hash, error_msg = error_item
        errors_object = @record.errors
        error_key_s = error_key.to_s

        return errors_object.full_message(error_key, error_msg) unless error_key_s.include?('.')

        # contains a '.' (nested attributes)
        # has_many :recognitions, dependent: :destroy, index_errors: true
        path = error_key_s.split('.')
        attribute = path.pop

        if (record = get_record_from_errors_path(@record, path))
          model_i18n = I18n.t("activerecord.models.#{record.class.name.underscore}.one")
          id = record.id || record.try(:lid_id)
          error_msgs = record.errors.full_message(attribute, error_msg)

          "(#{model_i18n} #{id}) #{error_msgs}"
        else
          errors_object.full_message(error_key, error_msg)
        end
      end

      # @param [Array] error_item
      # @return [Hash]
      def source(error_item)
        error_key = error_item[0]

        if @attrs&.include?(error_key)
          { pointer: "/data/attributes/#{error_key}" }
        elsif @rels&.include?(error_key)
          { pointer: "/data/relationships/#{error_key}" }
        else
          { pointer: '' }
        end
      end

      # @param [ActiveRecord::Base] instance
      # @param [Array] instance
      # @return [NilClass|ActiveRecord::Base]
      def get_record_from_errors_path(instance, path)
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
