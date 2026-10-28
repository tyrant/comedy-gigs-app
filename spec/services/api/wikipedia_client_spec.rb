require 'rails_helper'

RSpec.describe Api::WikipediaClient do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:client) { described_class.new(adapter: [ :test, stubs ]) }
  let(:json) { { 'Content-Type' => 'application/json' } }

  before { allow(client).to receive(:sleep) }

  after { stubs.verify_stubbed_calls }

  describe '#items_for_titles' do
    it 'looks the titles up on Wikidata, saying who is asking, and drops titles with no article' do
      stubs.get('/w/api.php') do |env|
        expect(env.params).to include('action' => 'wbgetentities', 'sites' => 'enwiki', 'titles' => 'Rose Matafeo|Rose Matafeo (comedian)')
        expect(env.request_headers['User-Agent']).to start_with 'ComedyGigs/'
        [ 200, json, { entities: { 'Q1' => { id: 'Q1' }, '-1' => { missing: '' } } }.to_json ]
      end

      expect(client.items_for_titles([ 'Rose Matafeo', 'Rose Matafeo (comedian)' ])).to eq [ { 'id' => 'Q1' } ]
    end

    it 'raises an error Wikidata reports' do
      stubs.get('/w/api.php') { [ 200, json, { error: { info: 'Too busy' } }.to_json ] }
      expect { client.items_for_titles([ 'X Y' ]) }.to raise_error(Api::ApiError, 'Wikidata: Too busy')
    end

    it 'retries when asked to slow down, then gives up' do
      stubs.get('/w/api.php') { [ 429, json, '{}' ] }
      expect { client.items_for_titles([ 'X Y' ]) }.to raise_error(Api::RateLimitError)
      expect(client).to have_received(:sleep).exactly(3).times
    end
  end

  describe '#summary' do
    def summary_page(title, **attrs)
      { type: 'standard', title:, extract: "#{title} is a comedian.",
        content_urls: { desktop: { page: "https://en.wikipedia.org/wiki/#{title.tr(' ', '_')}" } } }.merge(attrs).to_json
    end

    it 'is the article’s opening paragraph and address' do
      stubs.get('/api/rest_v1/page/summary/Rose_Matafeo') { [ 200, json, summary_page('Rose Matafeo') ] }

      expect(client.summary('Rose Matafeo')).to eq(text: 'Rose Matafeo is a comedian.', url: 'https://en.wikipedia.org/wiki/Rose_Matafeo')
    end

    it 'is nil for a disambiguation page, a redirect elsewhere, or no article' do
      stubs.get('/api/rest_v1/page/summary/Paul_Smith') { [ 200, json, summary_page('Paul Smith', type: 'disambiguation') ] }
      stubs.get('/api/rest_v1/page/summary/Mark_Cohen_%28comedian%29') { [ 200, json, summary_page('Make Me Laugh') ] }
      stubs.get('/api/rest_v1/page/summary/Nobody_Here') { [ 404, json, '{}' ] }

      expect([ client.summary('Paul Smith'), client.summary('Mark Cohen (comedian)'), client.summary('Nobody Here') ]).to all(be_nil)
    end
  end
end
