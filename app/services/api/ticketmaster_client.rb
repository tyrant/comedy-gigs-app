module Api
  class TicketmasterClient
    BASE_URL = "https://app.ticketmaster.com/discovery/v2".freeze
    COMEDY_SEGMENT_ID = "KZFzniwnSyZfZ7v7na".freeze # Ticketmaster's ID for Comedy events
    COMEDY_GENRE_ID = "KnvZfZ7vAe1".freeze # Ticketmaster's ID for Comedy genre

    MAX_RETRIES = 3
    RETRY_DELAY = 1 # seconds

    def initialize(api_key = nil)
      @api_key = api_key || fetch_api_key
      raise AuthenticationError, "Missing Ticketmaster API key" unless @api_key

      @client = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      @rate_limiter = RateLimiter.new("ticketmaster_api", max_requests: 5, interval: 1.second)
    end

    def test_connection
      with_retries do
        @rate_limiter.with_rate_limit do
          response = @client.get("events", {
            apikey: @api_key,
            size: 1
          })

          handle_response(response)
          true
        end
      rescue ApiError => e
        puts "API Error: #{e.message}"
        false
      end
    end

    def fetch_comedy_events(country_code: "NZ", size: 100, page: 0)
      with_retries do
        @rate_limiter.with_rate_limit do
          response = @client.get("events", {
            apikey: @api_key,
            countryCode: country_code,
            segmentId: COMEDY_SEGMENT_ID,
            genreId: COMEDY_GENRE_ID,
            size: size,
            page: page,
            sort: "date,asc",
            startDateTime: Time.current.iso8601
          })

          handle_response(response)
        end
      end
    end

    private

    def with_retries
      retries = 0
      begin
        yield
      rescue RateLimitError => e
        retries += 1
        if retries <= MAX_RETRIES
          sleep(RETRY_DELAY * retries) # Exponential backoff
          retry
        else
          raise RateLimitError, "Rate limit exceeded after #{MAX_RETRIES} retries"
        end
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        retries += 1
        if retries <= MAX_RETRIES
          sleep(RETRY_DELAY * retries)
          retry
        else
          raise ApiError, "Connection error after #{MAX_RETRIES} retries: #{e.message}"
        end
      end
    end

    def fetch_api_key
      return ENV["TICKETMASTER_API_KEY"] if ENV["TICKETMASTER_API_KEY"].present?
      return Rails.application.credentials.dig(:ticketmaster, :api_key) if Rails.application.credentials.dig(:ticketmaster, :api_key).present?
      nil
    end

    def handle_response(response)
      case response.status
      when 200
        response.body
      when 429
        raise RateLimitError, "Rate limit exceeded"
      when 401
        raise AuthenticationError, "Invalid API key"
      else
        raise ApiError, "Unexpected error: #{response.status}"
      end
    end
  end

  class ApiError < StandardError; end
  class RateLimitError < ApiError; end
  class AuthenticationError < ApiError; end
end
