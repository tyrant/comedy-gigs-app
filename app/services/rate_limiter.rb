class RateLimiter
  def initialize(key, max_requests: 5, interval: 1.second)
    @key = key
    @max_requests = max_requests
    @interval = interval
    @redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379/1")
  end

  def with_rate_limit
    return yield if allowed?

    wait_time = next_available_slot
    Rails.logger.info "Rate limit reached for #{@key}. Waiting #{wait_time} seconds..."
    sleep(wait_time)

    yield
  ensure
    record_request
  end

  private

  def allowed?
    current_requests < @max_requests
  end

  def current_requests
    recent_requests.count
  end

  def recent_requests
    requests = @redis.zrangebyscore(cache_key, min_time, max_time)
    # Clean up old entries
    @redis.zremrangebyscore(cache_key, "-inf", min_time)
    requests
  end

  def record_request
    @redis.zadd(cache_key, Time.current.to_f, SecureRandom.uuid)
  end

  def next_available_slot
    oldest_request = @redis.zrange(cache_key, 0, 0, with_scores: true)&.first
    return 0 unless oldest_request

    time_diff = Time.current.to_f - oldest_request[1]
    [ @interval - time_diff, 0 ].max
  end

  def cache_key
    "rate_limit:#{@key}"
  end

  def min_time
    (Time.current - @interval).to_f
  end

  def max_time
    Time.current.to_f
  end
end
