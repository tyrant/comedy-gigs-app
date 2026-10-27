require 'rails_helper'

RSpec.describe RateLimiter do
  let(:limiter) { described_class.new('test', max_requests: 2, interval: 1.second) }
  let(:clock) { [ 100.0 ] }

  before do
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock.first }
    allow(limiter).to receive(:sleep) { |seconds| clock[0] += seconds }
  end

  it 'returns the block value' do
    expect(limiter.with_rate_limit { :result }).to eq :result
  end

  it 'lets max_requests through without waiting' do
    2.times { limiter.with_rate_limit { } }
    expect(limiter).not_to have_received(:sleep)
  end

  it 'waits out the rest of the interval before the next request' do
    limiter.with_rate_limit { }
    clock[0] += 0.25
    limiter.with_rate_limit { }
    limiter.with_rate_limit { }
    expect(limiter).to have_received(:sleep).with(be_within(0.001).of(0.75))
  end

  it 'does not wait once the interval has passed' do
    2.times { limiter.with_rate_limit { } }
    clock[0] += 1.5
    limiter.with_rate_limit { }
    expect(limiter).not_to have_received(:sleep)
  end
end
