require 'rails_helper'

RSpec.describe Api::EventfindaClient do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:client) { described_class.new('user', 'secret', adapter: [ :test, stubs ]) }
  let(:json) { { 'Content-Type' => 'application/json' } }

  before do
    allow_any_instance_of(RateLimiter).to receive(:with_rate_limit).and_yield
    allow(client).to receive(:sleep)
  end

  after { stubs.verify_stubbed_calls }

  describe '#fetch_comedy_events' do
    it 'asks for a page of comedy by category ID, soonest first, with basic auth' do
      stubs.get('/v2/events.json') do |env|
        expect(env.params).to eq('category' => '48', 'rows' => '20', 'offset' => '40', 'order' => 'date')
        expect(env.request_headers['Authorization']).to eq "Basic #{Base64.strict_encode64('user:secret')}"
        [ 200, json, eventfinda_page([ eventfinda_event ], count: 41).to_json ]
      end

      page = client.fetch_comedy_events(offset: 40)
      expect(page.dig('@attributes', 'count')).to eq 41
      expect(page['events'].first['name']).to eq 'Late Night Laughs'
    end

    it 'explains a rejected request' do
      stubs.get('/v2/events.json') { [ 400, json, { code: 400, message: 'Invalid category' }.to_json ] }

      expect { client.fetch_comedy_events }.to raise_error(Api::ApiError, 'Eventfinda returned 400: Invalid category')
    end

    it 'reads the XML error that comes with bad credentials' do
      body = '<error code="1"><![CDATA[Incorrect authentication details supplied.]]></error>'
      stubs.get('/v2/events.json') { [ 401, { 'Content-Type' => 'application/xml' }, body ] }

      expect { client.fetch_comedy_events }.to raise_error(Api::AuthenticationError, 'Invalid Eventfinda API credentials')
    end

    it 'retries when rate limited, then gives up' do
      calls = 0
      stubs.get('/v2/events.json') { calls += 1; [ 429, json, '{}' ] }

      expect { client.fetch_comedy_events }.to raise_error(Api::RateLimitError)
      expect(calls).to eq described_class::MAX_RETRIES + 1
    end

    it 'retries a dropped connection' do
      calls = 0
      stubs.get('/v2/events.json') do
        calls += 1
        raise Faraday::ConnectionFailed, 'reset' if calls == 1

        [ 200, json, eventfinda_page([]).to_json ]
      end

      expect(client.fetch_comedy_events['events']).to eq []
    end
  end

  describe '#test_connection' do
    it { stubs.get('/v2/events.json') { [ 200, json, eventfinda_page([]).to_json ] }; expect(client.test_connection).to be true }
    it { stubs.get('/v2/events.json') { [ 500, json, '{}' ] }; expect(client.test_connection).to be false }
  end

  it 'refuses to start without credentials' do
    allow(Rails.application.credentials).to receive(:dig).and_return(nil)
    expect { described_class.new }.to raise_error(Api::AuthenticationError, /Missing Eventfinda API credentials/)
  end
end
