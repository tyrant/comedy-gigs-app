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

    describe 'storing hourly metrics' do
      let(:hourly_key) { "metrics:import:hourly:2025-06-14-12" }
      let(:stored_metrics) { redis.hgetall(hourly_key) }

      before { metrics.record_import(stats) }

      it { expect(stored_metrics["total_processed"]).to eq("10") }
      it { expect(stored_metrics["successful"]).to eq("8") }
      it { expect(stored_metrics["failed"]).to eq("1") }
      it { expect(stored_metrics["skipped"]).to eq("1") }
      it { expect(stored_metrics["rate_limited"]).to eq("0") }
      it { expect(redis.ttl(hourly_key)).to be_between(0, 24.hours.to_i) }
    end

    describe 'storing daily metrics' do
      let(:daily_key) { "metrics:import:daily:2025-06-14" }
      let(:stored_metrics) { redis.hgetall(daily_key) }

      before { metrics.record_import(stats) }

      it { expect(stored_metrics["total_processed"]).to eq("10") }
      it { expect(stored_metrics["successful"]).to eq("8") }
      it { expect(stored_metrics["failed"]).to eq("1") }
      it { expect(stored_metrics["skipped"]).to eq("1") }
      it { expect(stored_metrics["rate_limited"]).to eq("0") }
      it { expect(redis.ttl(daily_key)).to be_between(0, 30.days.to_i) }
    end

    describe 'updating running totals' do
      let(:totals) { redis.hgetall("metrics:import:totals") }

      before do
        metrics.record_import(stats)
        metrics.record_import(stats)  # Record twice
      end

      it { expect(totals["total_processed"]).to eq("20") }
      it { expect(totals["successful"]).to eq("16") }
      it { expect(totals["failed"]).to eq("2") }
      it { expect(totals["skipped"]).to eq("2") }
      it { expect(totals["rate_limited"]).to eq("0") }
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

    describe 'returning metrics for specified days' do
      let(:daily_metrics) { metrics.get_daily_metrics(3) }

      it { expect(daily_metrics.size).to eq(3) }
      it { expect(daily_metrics.first[:total_processed]).to eq(0) }
      it { expect(daily_metrics.last[:total_processed]).to eq(10) }
    end

    describe 'handling empty days in range' do
      let(:current_time) { Time.current }
      let(:key) { "metrics:import:daily:#{current_time.strftime('%Y-%m-%d')}" }

      before do
        redis.hmset(
          key,
          'total_processed', 10,
          'successful', 8,
          'failed', 1,
          'skipped', 1,
          'rate_limited', 0
        )
      end

      let(:daily_metrics) { metrics.get_daily_metrics(3) }

      it 'returns the requested number of days' do
        expect(daily_metrics.size).to eq(3)
      end

      it 'includes empty days with zero metrics' do
        expect(daily_metrics.first[:total_processed]).to eq(0)
      end

      it 'includes days with recorded metrics' do
        expect(daily_metrics.last[:total_processed]).to eq(10)
      end

      describe 'returning the requested number of days when hourly data exists' do
        before do
          # Record some test metrics for current hour
          hourly_key = "metrics:import:hourly:#{current_time.strftime('%Y-%m-%d-%H')}"
          redis.hmset(
            hourly_key,
            'total_processed', 5,
            'successful', 4,
            'failed', 1,
            'skipped', 0,
            'rate_limited', 0
          )

          # Set TTLs
          redis.expire(key, 30.days)
          redis.expire(hourly_key, 24.hours)
        end

        let(:daily_metrics) { metrics.get_daily_metrics(5) }

        it { expect(daily_metrics.size).to eq(5) }
        it { expect(daily_metrics.map { |m| m[:total_processed] }).to include(0) }
      end
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

    describe 'returning the requested number of hours' do
      let(:hourly_metrics) { metrics.get_hourly_metrics(3) }
      it { expect(hourly_metrics.size).to eq(3) }
    end

    describe 'including the current hour metrics' do
      let(:hourly_metrics) { metrics.get_hourly_metrics(3) }
      it { expect(hourly_metrics.last[:total_processed]).to eq(10) }
    end

    describe 'returns the requested number of hours when there are gaps' do
      before do
        Timecop.travel(Time.current - 2.hours) do
          metrics.record_import(
            total_processed: 0,
            successful: 0,
            failed: 0,
            skipped: 0,
            rate_limited: 0
          )
        end
      end
      let(:hourly_metrics) { metrics.get_hourly_metrics(5) }
      it { expect(hourly_metrics.size).to eq(5) }
      it { expect(hourly_metrics.map { |m| m[:total_processed] }).to include(0) }
    end
  end
end
