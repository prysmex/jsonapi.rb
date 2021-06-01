require 'rack/media_type'

module RailsJSONAPI
  class MediaTypeFilter
    JSONAPI_MEDIA_TYPE = ::RailsJSONAPI::MEDIA_TYPE

    def initialize(app)
      @app = app
    end

    def call env
      dup._call env
    end

    # Use duplicated object for Thread Safety
    # https://ieftimov.com/post/writing-rails-middleware/
    def _call(env)
      return [415, {}, []] unless valid_content_type?(env['CONTENT_TYPE'])
      return [406, {}, []] unless valid_accept?(env['HTTP_ACCEPT'])

      @app.call(env)
    end

    private

    def valid_content_type?(content_type)
      Rack::MediaType.type(content_type) != JSONAPI_MEDIA_TYPE ||
        Rack::MediaType.params(content_type) == {}
    end

    def valid_accept?(accept)
      return true if accept.nil?

      jsonapi_media_types =
        accept.split(',')
              .map(&:strip)
              .select { |m| Rack::MediaType.type(m) == JSONAPI_MEDIA_TYPE }

      jsonapi_media_types.empty? ||
        jsonapi_media_types.any? { |m| Rack::MediaType.params(m) == {} }
    end
  end
end