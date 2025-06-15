require 'rails_helper'

RSpec.describe Metrics::ImportMetrics do
  let(:redis) { Redis.new }
  let(:metrics) { described_class.new }
  let(:stats) do
    {
      total_processed: 10,
      successful: 8,
      failed: 1,
      skipped: 1,
      rate_limited: 0
    }
  end

  before do
    allow(Redis).to receive(:new).and_return(redis)
    redis.flushdb  # Clear Redis before each test
  end

  describe '#record_import' do
    before do
      allow(Time).to receive(:current).and_return(
        Time.new(2025, 6, 14, 12, 0, 0)
      )
    end

    it 'stores hourly metrics' do
      metrics.record_import(stats)

      hourly_key = "metrics:import:hourly:2025-06-14-12"
      stored_metrics = redis.hgetall(hourly_key)

      expect(stored_metrics["total_processed"]).to eq("10")
      expect(stored_metrics["successful"]).to eq("8")
      expect(stored_metrics["failed"]).to eq("1")
      expect(stored_metrics["skipped"]).to eq("1")
      expect(stored_metrics["rate_limited"]).to eq("0")

      # Check TTL is set
      expect(redis.ttl(hourly_key)).to be_between(0, 24.hours.to_i)
    end

    it 'stores daily metrics' do
      metrics.record_import(stats)

      daily_key = "metrics:import:daily:2025-06-14"
      stored_metrics = redis.hgetall(daily_key)

      expect(stored_metrics["total_processed"]).to eq("10")
      expect(stored_metrics["successful"]).to eq("8")
      expect(stored_metrics["failed"]).to eq("1")
      expect(stored_metrics["skipped"]).to eq("1")
      expect(stored_metrics["rate_limited"]).to eq("0")

      # Check TTL is set
      expect(redis.ttl(daily_key)).to be_between(0, 30.days.to_i)
    end

    it 'updates running totals' do
      metrics.record_import(stats)
      metrics.record_import(stats)  # Record twice

      totals = redis.hgetall("metrics:import:totals")

      expect(totals["total_processed"]).to eq("20")
      expect(totals["successful"]).to eq("16")
      expect(totals["failed"]).to eq("2")
      expect(totals["skipped"]).to eq("2")
      expect(totals["rate_limited"]).to eq("0")
    end
  end

  describe '#get_daily_metrics' do
    before do
      Timecop.freeze(Time.current)
      # Record test data for today
      redis.hmset(
        "metrics:import:daily:#{Time.current.strftime('%Y-%m-%d')}",
        'total_processed', 10,
        'successful', 8,
        'failed', 1,
        'skipped', 1,
        'rate_limited', 0
      )
    end

    it 'returns metrics for the specified number of days' do
      daily_metrics = metrics.get_daily_metrics(3)
      expect(daily_metrics.size).to eq(3)
      expect(daily_metrics.first[:total_processed]).to eq(0)
      expect(daily_metrics.last[:total_processed]).to eq(10)
    end

    it 'includes empty days in the range' do
      # Record some test metrics for today
      current_time = Time.current
      key = "metrics:import:daily:#{current_time.strftime('%Y-%m-%d')}"
      redis.hmset(
        key,
        'total_processed', 10,
        'successful', 8,
        'failed', 1,
        'skipped', 1
      )

      # Record some test metrics for current hour
      key = "metrics:import:hourly:#{current_time.strftime('%Y-%m-%d-%H')}"
      redis.hmset(
        key,
        'total_processed', 10,
        'successful', 8,
        'failed', 1,
        'skipped', 1
      )

      daily_metrics = metrics.get_daily_metrics(5)
      expect(daily_metrics.size).to eq(5)
      expect(daily_metrics.map { |m| m[:total_processed] }).to include(0)
    end
  end

  describe '#get_hourly_metrics' do
    before do
      Timecop.freeze(Time.current)
      # Record test data for current hour
      redis.hmset(
        "metrics:import:hourly:#{Time.current.strftime('%Y-%m-%d-%H')}",
        'total_processed', 10,
        'successful', 8,
        'failed', 1,
        'skipped', 1,
        'rate_limited', 0
      )
    end

    it 'returns metrics for the specified number of hours' do
      hourly_metrics = metrics.get_hourly_metrics(3)
      expect(hourly_metrics.size).to eq(3)
      expect(hourly_metrics.last[:total_processed]).to eq(10)
    end

    it 'includes empty hours in the range' do
      # Add a gap in the data
      Timecop.travel(Time.current - 2.hours) do
        metrics.record_import(
          total_processed: 0,
          successful: 0,
          failed: 0,
          skipped: 0,
          rate_limited: 0
        )
      end
      hourly_metrics = metrics.get_hourly_metrics(5)
      expect(hourly_metrics.size).to eq(5)
      expect(hourly_metrics.map { |m| m[:total_processed] }).to include(0)
    end
  end
end
