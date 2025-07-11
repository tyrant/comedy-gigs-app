module Metrics
  class ImportMetrics
    METRICS_TTL = 30.days

    def initialize
      @redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    end

    def record_import(stats)
      # Store hourly metrics
      hour_key = "metrics:import:hourly:#{Time.current.strftime('%Y-%m-%d-%H')}"
      store_metrics(hour_key, stats, 24.hours)

      # Store daily metrics
      day_key = "metrics:import:daily:#{Time.current.strftime('%Y-%m-%d')}"
      store_metrics(day_key, stats, METRICS_TTL)

      # Update running totals
      update_totals(stats)
    end

    def get_daily_metrics(days)
      current_date = Time.current.beginning_of_day
      (0..days-1).map do |i|
        date = current_date - i.days
        key = "metrics:import:daily:#{date.strftime('%Y-%m-%d')}"
        metrics = @redis.hgetall(key)
        metrics.transform_values!(&:to_i)
        {
          total_processed: metrics["total_processed"] || 0,
          successful: metrics["successful"] || 0,
          failed: metrics["failed"] || 0,
          skipped: metrics["skipped"] || 0,
          rate_limited: metrics["rate_limited"] || 0
        }.merge(date: date)
      end.reverse
    end

    def get_hourly_metrics(hours)
      current_hour = Time.current.beginning_of_hour
      (0..hours-1).map do |i|
        hour = current_hour - i.hours
        key = "metrics:import:hourly:#{hour.strftime('%Y-%m-%d-%H')}"
        metrics = @redis.hgetall(key)
        metrics.transform_values!(&:to_i)
        {
          total_processed: metrics["total_processed"] || 0,
          successful: metrics["successful"] || 0,
          failed: metrics["failed"] || 0,
          skipped: metrics["skipped"] || 0,
          rate_limited: metrics["rate_limited"] || 0
        }.merge(hour: hour)
      end.reverse
    end

    def get_totals
      get_metrics("metrics:import:totals")
    end

    private

    def store_metrics(key, stats, ttl)
      @redis.multi do |multi|
        multi.hincrby(key, "total_processed", stats[:total_processed].to_i)
        multi.hincrby(key, "successful", stats[:successful].to_i)
        multi.hincrby(key, "failed", stats[:failed].to_i)
        multi.hincrby(key, "skipped", stats[:skipped].to_i)
        multi.hincrby(key, "rate_limited", stats[:rate_limited].to_i)
        multi.expire(key, ttl)
      end
    end

    def update_totals(stats)
      store_metrics("metrics:import:totals", stats, METRICS_TTL)
    end

    def get_metrics(key)
      metrics = @redis.hgetall(key)
      metrics.transform_values!(&:to_i)
      {
        total_processed: 0,
        successful: 0,
        failed: 0,
        skipped: 0,
        rate_limited: 0
      }.merge(metrics)
    end
  end
end
