module Api
  # Wikidata and English Wikipedia's public APIs. They need no key, but ask
  # callers to say who they are in the User-Agent.
  class WikipediaClient
    USER_AGENT = "ComedyGigs/1.0 (https://sexyverse.email)".freeze

    MAX_RETRIES = 3
    RETRY_DELAY = 2 # seconds, multiplied by the attempt number

    # adapter: a Faraday adapter, for specs to stub the HTTP calls
    def initialize(adapter: nil)
      @wikidata = connection("https://www.wikidata.org", adapter)
      @wikipedia = connection("https://en.wikipedia.org", adapter)
    end

    # The Wikidata items for these English Wikipedia article titles (following
    # redirects), with their claims; titles with no article are left out
    def items_for_titles(titles)
      body = get(@wikidata, "/w/api.php", action: "wbgetentities", sites: "enwiki", titles: titles.join("|"),
                                          props: "claims|sitelinks", sitefilter: "enwiki", format: "json")
      raise ApiError, "Wikidata: #{body.dig('error', 'info')}" if body["error"]

      (body["entities"] || {}).reject { |id, _item| id.start_with?("-") }.values
    end

    # { text:, url: } from the article's opening paragraph, or nil for no
    # article, a disambiguation page, or a redirect: a comedian's title can
    # redirect to an article about something else ("Mark Cohen (comedian)"
    # goes to the game show he hosted)
    def summary(title)
      body = get(@wikipedia, "/api/rest_v1/page/summary/#{ERB::Util.url_encode(title.tr(' ', '_'))}")
      return nil if body.nil? || body["type"] != "standard" || body["extract"].blank?
      return nil unless body["title"].to_s.tr("_", " ") == title.tr("_", " ")

      { text: body["extract"], url: body.dig("content_urls", "desktop", "page") }
    end

    private

    def connection(url, adapter)
      Faraday.new(url:, headers: { "User-Agent" => USER_AGENT }) do |f|
        f.response :json, content_type: /\bjson$/
        f.options.timeout = 20
        f.options.open_timeout = 10
        f.adapter(*adapter) if adapter
      end
    end

    def get(client, path, params = {})
      attempts = 0
      begin
        attempts += 1
        handle_response(client.get(path, params))
      rescue RateLimitError, Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise(e.is_a?(RateLimitError) ? e : ApiError.new("Connection error: #{e.message}")) if attempts > MAX_RETRIES

        sleep(RETRY_DELAY * attempts)
        retry
      end
    end

    def handle_response(response)
      case response.status
      when 200 then response.body
      when 404 then nil
      when 429, 503 then raise RateLimitError, "Wikimedia asked us to slow down (#{response.status})"
      else raise ApiError, "Wikimedia returned #{response.status}"
      end
    end
  end
end
