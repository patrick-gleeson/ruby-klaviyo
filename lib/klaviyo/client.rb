module Klaviyo
  class Client
    BASE_API_URL = 'https://a.klaviyo.com/api'
    V1_API = 'v1'
    V2_API = 'v2'

    HTTP_DELETE = 'delete'
    HTTP_GET = 'get'
    HTTP_POST = 'post'
    HTTP_PUT = 'put'

    ALL = 'all'
    METRIC = 'metric'
    METRICS = 'metrics'
    TIMELINE = 'timeline'

    DEFAULT_COUNT = 100
    DEFAULT_PAGE = 0
    DEFAULT_SORT_DESC = 'desc'

    CONTENT_JSON = 'application/json'
    CONTENT_URL_FORM = 'application/x-www-form-urlencoded'

    private

    def self.request(method, path, content_type, **kwargs)
      check_private_api_key_exists()
      url = "#{BASE_API_URL}/#{path}"
      connection = Faraday.new(
        url: url,
        headers: {
          'Content-Type' => content_type
      })
      if content_type == CONTENT_JSON
        kwargs[:body] = kwargs[:body].to_json
      end
      response = connection.send(method) do |req|
        req.body = kwargs[:body] || nil
      end
    end

    def self.public_request(method, path, **kwargs)
      check_public_api_key_is_valid()
      if method == HTTP_GET
        params = build_params(kwargs)
        url = "#{BASE_API_URL}/#{path}?#{params}"
        res = Faraday.get(url).body
      elsif method == HTTP_POST
        url = URI("#{BASE_API_URL}/#{path}")
        response = Faraday.post(url) do |req|
          req.headers['Content-Type'] = CONTENT_URL_FORM
          req.headers['Accept'] = 'text/html'
          req.body = {data: "#{kwargs.to_json}"}
        end
      else
        raise KlaviyoError.new(INVALID_HTTP_METHOD)
      end
    end

    def self.v1_request(method, path, content_type: CONTENT_JSON, **kwargs)
      if content_type == CONTENT_URL_FORM
        data = {
          :body => {
            :api_key => Klaviyo.private_api_key
          }
        }
        data[:body] = data[:body].merge(kwargs[:params])
        full_url = "#{V1_API}/#{path}"
        request(method, full_url, content_type, **data)
      else
        defaults = {:page => nil,
                    :count => nil,
                    :since => nil,
                    :sort => nil}
        params = defaults.merge(kwargs)
        query_params = encode_params(params)
        full_url = "#{V1_API}/#{path}?api_key=#{Klaviyo.private_api_key}#{query_params}"
        request(method, full_url, content_type)
      end
    end

    def self.v2_request(method, path, **kwargs)
      path = "#{V2_API}/#{path}"
      key = {
        "api_key": "#{Klaviyo.private_api_key}"
      }
      data = {}
      data[:body] = key.merge(kwargs)
      request(method, path, CONTENT_JSON, **data)
    end

    def self.build_params(params)
      "data=#{CGI.escape(Base64.encode64(JSON.generate(params)).gsub(/\n/, ''))}"
    end

    def self.check_required_args(kwargs)
      if kwargs[:email].to_s.empty? and kwargs[:phone_number].to_s.empty? and kwargs[:id].to_s.empty?
        raise Klaviyo::KlaviyoError.new(REQUIRED_ARG_ERROR)
      else
        return true
      end
    end

    def self.check_private_api_key_exists()
      if !Klaviyo.private_api_key
        raise KlaviyoError.new(NO_PRIVATE_API_KEY_ERROR)
      end
    end

    def self.check_public_api_key_is_valid()
      if !Klaviyo.public_api_key
        raise KlaviyoError.new(NO_PUBLIC_API_KEY_ERROR)
      end
      if ( Klaviyo.public_api_key =~ /pk_\w{34}$/ ) == 0
        raise KlaviyoError.new(PRIVATE_KEY_AS_PUBLIC)
      end
      if ( Klaviyo.public_api_key =~ /\w{6}$/ ) != 0
        raise KlaviyoError.new(INCORRECT_PUBLIC_API_KEY_LENGTH)
      end
    end

    def self.encode_params(kwargs)
      kwargs.select!{|k, v| v}
      params = URI.encode_www_form(kwargs)

      if !params.empty?
        return "&#{params}"
      end
    end
  end
end
