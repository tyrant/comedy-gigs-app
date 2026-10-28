module Api
  # Eventfinda's API v2 for New Zealand (https://www.eventfinda.co.nz/api/v2).
  # Australia and Singapore are separate sites that need their own API keys.
  class EventfindaClient
    BASE_URL = "https://api.eventfinda.co.nz/v2".freeze

    # Category filters take numeric IDs; the "comedy" slug is rejected with a 400.
    # 48 is Performing Arts > Comedy (see categories.json).
    COMEDY_CATEGORY_ID = 48
    PAGE_SIZE = 20 # the API's maximum

    MAX_RETRIES = 3
    RETRY_DELAY = 1 # seconds, multiplied by the attempt number

    # adapter: a Faraday adapter, for specs to stub the HTTP calls
    def initialize(username = nil, password = nil, adapter: nil)
      @username = username || credential(:username)
      @password = password || credential(:password)
      raise AuthenticationError, "Missing Eventfinda API credentials" unless @username.present? && @password.present?

      @client = Faraday.new(url: BASE_URL) do |f|
        f.request :authorization, :basic, @username, @password
        f.response :json, content_type: /\bjson$/
        f.options.timeout = 30
        f.options.open_timeout = 10
        f.adapter(*adapter) if adapter
      end

      # Eventfinda asks for no more than one request a second
      @rate_limiter = RateLimiter.new("eventfinda_api", max_requests: 1, interval: 1.second)
    end

    def test_connection
      get("events.json", rows: 1)
      true
    rescue ApiError
      false
    end

    # One page of upcoming comedy events, soonest first. The response's
    # @attributes.count is the total; pages sometimes hold fewer than
    # PAGE_SIZE events, so page by offset against that count.
    def fetch_comedy_events(offset: 0, rows: PAGE_SIZE)
      get("events.json", category: COMEDY_CATEGORY_ID, rows:, offset:, order: "date")
    end

    private

    def get(path, params)
      with_retries do
        @rate_limiter.with_rate_limit { handle_response(@client.get(path, params)) }
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

    def credential(name)
      ENV["EVENTFINDA_#{name.upcase}"].presence || Rails.application.credentials.dig(:eventfinda, name).presence
    end

    def handle_response(response)
      case response.status
      when 200 then response.body
      when 401 then raise AuthenticationError, "Invalid Eventfinda API credentials"
      when 429 then raise RateLimitError, "Eventfinda rate limit exceeded"
      else raise ApiError, "Eventfinda returned #{response.status}: #{error_message(response.body)}"
      end
    end

    # Errors come as JSON ({"message": ...}) or, for authentication, XML
    def error_message(body)
      message = body.is_a?(Hash) ? body["message"] : body.to_s[/CDATA\[(.*?)\]\]/, 1] || body.to_s
      message.to_s.squish.truncate(200)
    end
  end
end
