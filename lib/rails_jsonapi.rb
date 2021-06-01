require 'rails_jsonapi/error_serializer'
require 'rails_jsonapi/active_model_error_serializer'
require 'rails_jsonapi/controller_error_hooks'
require 'rails_jsonapi/controller'
require 'rails_jsonapi/deserialization'
require 'rails_jsonapi/railtie'
require 'rails_jsonapi/version'

module RailsJSONAPI
  # JSONAPI media type.
  MEDIA_TYPE = 'application/vnd.api+json'.freeze
end
