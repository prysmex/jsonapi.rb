# frozen_string_literal: true

require 'rails_jsonapi/error_serializer/base'
require 'rails_jsonapi/error_serializer/active_model'
require 'rails_jsonapi/controller'
require 'rails_jsonapi/deep_deserializer'
require 'rails_jsonapi/media_type_filter'
require 'rails_jsonapi/railtie'
require 'rails_jsonapi/version'

module RailsJSONAPI
  # JSONAPI media type.
  MEDIA_TYPE = 'application/vnd.api+json'

  # caches
  @_serializable_cache   = {}
  @_deserializable_cache = {}
  @_caches = [@_serializable_cache, @_deserializable_cache]

  @class_to_serializer_proc = lambda do |klass|
    @_serializable_cache[klass] ||= "#{klass.name}Serializer".constantize
  end

  @class_to_multimodel_serializer_proc = @class_to_serializer_proc

  @class_to_errors_serializer_proc = lambda do |klass|
    if klass == ActiveModel::Errors
      RailsJSONAPI::ErrorSerializer::ActiveModel
    else
      RailsJSONAPI::ErrorSerializer::Base
    end
  end

  # deserializer must return [Hash{Symbol => *}]
  @type_to_deserializer_proc = lambda do |type|
    u_s = type.underscore
    @_deserializable_cache[u_s] ||= "#{u_s.classify}Deserializer".constantize
  end

  class << self
    attr_accessor :class_to_serializer_proc,
                  :class_to_multimodel_serializer_proc,
                  :class_to_errors_serializer_proc,
                  :type_to_deserializer_proc,
                  :force_content_type

    def configure
      yield self
    end

    def reset_caches!
      @_caches.each(&:clear)
    end
  end
end

