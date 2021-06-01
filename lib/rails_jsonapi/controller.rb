module RailsJSONAPI
  # Inclusion and sparse fields support
  module Controller

    # @return [Boolean] true when request contains jsonapi mime
    def json_api_request?
      request
        .try(:content_mime_type)
        .try(:instance_variable_get, '@string') == ::RailsJSONAPI::MEDIA_TYPE
    end

    # Extracts and formats 'fields' jsonapi param
    #
    # Ex.: `GET /resource?fields[relationship]=id,created_at`
    #
    # @return [Hash]
    def jsonapi_fields_param
      return {} unless params[:fields].respond_to?(:each_pair)

      instance = if defined?(ActiveSupport::HashWithIndifferentAccess)
        ActiveSupport::HashWithIndifferentAccess.new
      else
        Hash.new
      end

      params[:fields].each_with_object(instance) do |(k, v), obj|
        obj[k] = v.to_s.split(',').map(&:strip).compact
      end
    end

    # Extracts and formats 'include' jsonapi param
    #
    # Ex.: `GET /resource?include=relationship,relationship.subrelationship`
    #
    # @return [Array]
    def jsonapi_include_param
      _include = case params['include']
        when String
          params['include'].to_s.split(',')
        when Array
          params['include']
        else
          []
        end

      _include&.map(&:strip)&.compact
    end
  end
end
