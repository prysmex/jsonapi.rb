require 'rails_jsonapi/error_serializer/base'
require 'rails_jsonapi/error_serializer/active_model'
require 'rails_jsonapi/controller'
require 'rails_jsonapi/deep_deserializer'
require 'rails_jsonapi/media_type_filter'
require 'rails_jsonapi/railtie'
require 'rails_jsonapi/version'

module RailsJSONAPI
  # JSONAPI media type.
  MEDIA_TYPE = 'application/vnd.api+json'.freeze

  @class_to_serializer_proc = ->(klass){ "#{klass.name}Serializer".constantize }

  @type_to_deserializer_proc = ->(type){ "#{type.underscore.classify}Deserializer".constantize }

  class << self

    attr_accessor :class_to_serializer_proc, :type_to_deserializer_proc

    def configure
      yield self
    end
  end

end
