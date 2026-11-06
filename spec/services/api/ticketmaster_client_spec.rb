require 'rails_helper'

RSpec.describe Api::TicketmasterClient do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:client) { described_class.new('test-key', adapter: [ :test, stubs ]) }
  let(:json) { { 'Content-Type' => 'application/json' } }

  before { allow_any_instance_of(RateLimiter).to receive(:with_rate_limit).and_yield }

  after { stubs.verify_stubbed_calls }

  describe '#fetch_comedy_events' do
    it 'asks for comedy in every language, between two times' do
      stubs.get('/discovery/v2/events') do |env|
        expect(env.params).to include('apikey' => 'test-key', 'segmentId' => described_class::COMEDY_SEGMENT_ID,
                                      'genreId' => described_class::COMEDY_GENRE_ID, 'locale' => '*', 'countryCode' => 'FR',
                                      'page' => '2', 'size' => '100', 'sort' => 'date,asc',
                                      'startDateTime' => '2030-03-01T00:00:00Z', 'endDateTime' => '2030-03-08T00:00:00Z')
        [ 200, json, { 'page' => { 'totalElements' => 0 } }.to_json ]
      end

      response = client.fetch_comedy_events(country_code: 'FR', page: 2, starts_after: Time.utc(2030, 3, 1),
                                            starts_before: Time.utc(2030, 3, 8))
      expect(response.dig('page', 'totalElements')).to eq 0
    end

    it 'treats a 401 as a bad key' do
      stubs.get('/discovery/v2/events') { [ 401, json, '{}' ] }

      expect { client.fetch_comedy_events }.to raise_error(Api::AuthenticationError, 'Invalid API key')
    end
  end
end
