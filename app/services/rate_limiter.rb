# Spaces out calls to an external API so no more than max_requests start in
# any rolling interval. Imports run as a single sequential process, so the
# window lives in memory; there's nothing to share across processes.
class RateLimiter
  def initialize(key, max_requests: 5, interval: 1.second)
    @key = key
    @max_requests = max_requests
    @interval = interval.to_f
    @started_at = []
  end

  def with_rate_limit
    wait_for_slot
    @started_at << monotonic_now
    yield
  end

  private

  def wait_for_slot
    prune
    return if @started_at.size < @max_requests

    wait_time = @interval - (monotonic_now - @started_at.first)
    if wait_time.positive?
      Rails.logger.debug "Rate limit reached for #{@key}. Waiting #{wait_time.round(3)}s"
      sleep(wait_time)
    end
    prune
  end

  def prune
    cutoff = monotonic_now - @interval
    @started_at.shift while @started_at.any? && @started_at.first <= cutoff
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
