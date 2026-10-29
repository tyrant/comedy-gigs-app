require 'rails_helper'

RSpec.describe Api::SkiddleClient do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:client) { described_class.new('test-key', adapter: [ :test, stubs ]) }
  let(:json) { { 'Content-Type' => 'application/json' } }

  before do
    allow_any_instance_of(RateLimiter).to receive(:with_rate_limit).and_yield
    allow(client).to receive(:sleep)
  end

  after { stubs.verify_stubbed_calls }

  describe '#fetch_comedy_events' do
    it 'asks for a page of UK comedy with artists, between two dates' do
      stubs.get('/api/v1/events/search/') do |env|
        expect(env.params).to eq('eventcode' => 'COMEDY', 'country' => 'GB', 'description' => '1', 'limit' => '100',
                                 'offset' => '200', 'minDate' => '2030-03-01', 'maxDate' => '2031-03-01', 'api_key' => 'test-key')
        [ 200, json, skiddle_page([ skiddle_event ], totalcount: 201).to_json ]
      end

      page = client.fetch_comedy_events(offset: 200, from: Date.new(2030, 3, 1), to: Date.new(2031, 3, 1))
      expect(page['totalcount']).to eq '201'
      expect(page['results'].first['eventname']).to eq 'Thursday Night Laughs'
    end

    it 'leaves out an open end date' do
      stubs.get('/api/v1/events/search/') do |env|
        expect(env.params).not_to have_key('maxDate')
        [ 200, json, skiddle_page([]).to_json ]
      end

      client.fetch_comedy_events
    end

    it 'treats a 403 as a bad key' do
      stubs.get('/api/v1/events/search/') { [ 403, json, { error: 1, errormessage: 'Rate Limit check could not run', errorcode: 999 }.to_json ] }

      expect { client.fetch_comedy_events }.to raise_error(Api::AuthenticationError, 'Invalid Skiddle API key')
    end

    it 'treats a complaint about the key as a bad key' do
      stubs.get('/api/v1/events/search/') { [ 400, json, { error: 1, errormessage: 'A valid API Key must be provided', errorcode: 998 }.to_json ] }

      expect { client.fetch_comedy_events }.to raise_error(Api::AuthenticationError)
    end

    it 'explains any other error, even one that comes with a 200' do
      stubs.get('/api/v1/events/search/') { [ 200, json, { error: 1, errormessage: 'Invalid date', errorcode: 12 }.to_json ] }

      expect { client.fetch_comedy_events }.to raise_error(Api::ApiError, 'Skiddle returned 200: Invalid date')
    end

    it 'retries when rate limited, then gives up' do
      calls = 0
      stubs.get('/api/v1/events/search/') { calls += 1; [ 429, json, '{}' ] }

      expect { client.fetch_comedy_events }.to raise_error(Api::RateLimitError)
      expect(calls).to eq described_class::MAX_RETRIES + 1
    end

    it 'retries a dropped connection' do
      calls = 0
      stubs.get('/api/v1/events/search/') do
        calls += 1
        raise Faraday::ConnectionFailed, 'reset' if calls == 1

        [ 200, json, skiddle_page([]).to_json ]
      end

      expect(client.fetch_comedy_events['results']).to eq []
    end
  end

  it 'needs a key' do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:skiddle, :api_key).and_return(nil)

    expect { described_class.new }.to raise_error(Api::AuthenticationError, 'Missing Skiddle API key')
  end
end
