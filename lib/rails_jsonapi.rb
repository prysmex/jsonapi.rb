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
end
