module Api
  # Skiddle's events API for the UK (https://github.com/Skiddle/web-api/wiki).
  # Its terms: non-commercial use, credit Skiddle by name and logo wherever
  # its data appears, and link to each event's Skiddle page.
  class SkiddleClient
    BASE_URL = "https://www.skiddle.com/api/v1/".freeze

    COMEDY_EVENT_CODE = "COMEDY".freeze
    COUNTRY = "GB".freeze
    PAGE_SIZE = 100 # the API's maximum

    MAX_RETRIES = 3
    RETRY_DELAY = 1 # seconds, multiplied by the attempt number

    # adapter: a Faraday adapter, for specs to stub the HTTP calls
    def initialize(api_key = nil, adapter: nil)
      @api_key = api_key || ENV["SKIDDLE_API_KEY"].presence || Rails.application.credentials.dig(:skiddle, :api_key).presence
      raise AuthenticationError, "Missing Skiddle API key" if @api_key.blank?

      @client = Faraday.new(url: BASE_URL) do |f|
        f.response :json, content_type: /\bjson$/
        f.options.timeout = 30
        f.options.open_timeout = 10
        f.adapter(*adapter) if adapter
      end

      # Skiddle has hourly and daily limits on free keys; a nightly import
      # needs a few dozen requests, so one a second is plenty polite
      @rate_limiter = RateLimiter.new("skiddle_api", max_requests: 1, interval: 1.second)
    end

    def test_connection
      search(limit: 1)
      true
    rescue ApiError
      false
    end

    # One page of upcoming UK comedy, with artists. "totalcount" is the total.
    def fetch_comedy_events(offset: 0, limit: PAGE_SIZE, from: Date.current, to: nil)
      search(eventcode: COMEDY_EVENT_CODE, country: COUNTRY, description: 1, limit:, offset:,
             minDate: from.to_date.iso8601, maxDate: to&.to_date&.iso8601)
    end

    private

    def search(params)
      get("events/search/", params.compact)
    end

    def get(path, params)
      with_retries do
        @rate_limiter.with_rate_limit { handle_response(@client.get(path, params.merge(api_key: @api_key))) }
      end
    end

    def with_retries
      attempts = 0
      begin
        attempts += 1
        yield
      rescue RateLimitError, Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise(e.is_a?(RateLimitError) ? e : ApiError.new("Connection error: #{e.message}")) if attempts > MAX_RETRIES

        sleep(RETRY_DELAY * attempts)
        retry
      end
    end

    # Skiddle reports errors in the body ({"error": 1, "errormessage": ...}),
    # sometimes with a 200
    def handle_response(response)
      body = response.body
      case response.status
      when 200 then return body if !body.is_a?(Hash) || body["error"].to_i.zero?
      when 401, 403 then raise AuthenticationError, "Invalid Skiddle API key"
      when 429 then raise RateLimitError, "Skiddle rate limit exceeded"
      end

      message = error_message(body)
      raise AuthenticationError, "Invalid Skiddle API key" if message.match?(/api.?key/i)

      raise ApiError, "Skiddle returned #{response.status}: #{message}"
    end

    def error_message(body)
      message = body.is_a?(Hash) ? body["errormessage"] || body["message"] || body["error"] : body
      message.to_s.squish.truncate(200)
    end
  end
end
