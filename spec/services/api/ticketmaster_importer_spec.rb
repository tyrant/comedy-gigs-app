require 'rails_helper'

RSpec.describe Api::TicketmasterImporter do
  let(:client) { instance_double(Api::TicketmasterClient) }
  let(:importer) { described_class.new }

  before { allow(Api::TicketmasterClient).to receive(:new).and_return(client) }

  # Missing a venue location and attractions, so the transformer skips it
  let(:event_data) do
    {
      'name' => 'Test Comedy Show',
      'dates' => { 'start' => { 'dateTime' => '2025-06-14T20:00:00Z' } },
      '_embedded' => { 'venues' => [ { 'name' => 'Test Venue', 'city' => { 'name' => 'Auckland' } } ] }
    }
  end

  let(:api_response) { { '_embedded' => { 'events' => [ event_data ] }, 'page' => { 'totalPages' => 1 } } }

  # A single one-week window, so each stubbed response is fetched once
  subject(:stats) { importer.import_events(horizon: 7.days) }

  describe 'a run with nothing to import' do
    before { allow(client).to receive(:fetch_comedy_events).and_return(api_response) }

    it 'counts the event as processed and skipped' do
      expect(stats).to include(total_processed: 1, successful: 0, failed: 0, skipped: 1, rate_limited: 0)
    end

    it { expect(stats).not_to have_key(:error) }
    it { expect(stats[:start_time]).to be <= stats[:end_time] }
  end

  describe 'paging within a window' do
    let(:deep_response) { { '_embedded' => { 'events' => [ event_data ] }, 'page' => { 'totalPages' => 100 } } }

    before do
      allow(client).to receive(:fetch_comedy_events).and_return(deep_response)
      stats
    end

    it 'stops at the 1000-item ceiling instead of paging into a 400' do
      expect(client).to have_received(:fetch_comedy_events).exactly(described_class::MAX_PAGES).times
    end
  end

  describe 'a window holding more events than the API will page through' do
    let(:crowded_response) { { '_embedded' => { 'events' => [ event_data ] }, 'page' => { 'totalPages' => 100, 'totalElements' => 10_000 } } }
    let(:windows) { [] }

    before do
      allow(client).to receive(:fetch_comedy_events) do |starts_after:, starts_before:, **|
        windows << [ starts_after, starts_before ]
        (starts_before - starts_after) > 2.days ? crowded_response : api_response
      end
      stats
    end

    it 'halves the window until each part fits under the ceiling' do
      imported = windows.select { |from, to| (to - from) <= 2.days }
      expect(imported.size).to eq 4
      expect(imported.first.first).to eq windows.first.first
      expect(imported.last.last).to eq windows.first.last
      imported.each_cons(2) { |(_, end1), (start2, _)| expect(start2).to eq end1 }
    end
  end

  describe 'a horizon spanning several windows' do
    let(:windows) { [] }

    before do
      allow(client).to receive(:fetch_comedy_events) do |starts_after:, starts_before:, **|
        windows << [ starts_after, starts_before ]
        api_response
      end
      importer.import_events(horizon: 30.days)
    end

    it 'walks contiguous week-long windows up to the horizon' do
      expect(windows.map { |from, to| to - from }).to eq [ 7.days, 7.days, 7.days, 7.days, 2.days ]
      windows.each_cons(2) { |(_, end1), (start2, _)| expect(start2).to eq end1 }
    end
  end

  describe 'a fatal API error' do
    before { allow(client).to receive(:fetch_comedy_events).and_raise(Api::AuthenticationError, 'Invalid API key') }

    it 'records the error rather than raising, for the rake task to report' do
      expect(stats[:error]).to eq(class: 'Api::AuthenticationError', message: 'Invalid API key')
      expect(stats[:end_time]).to be_present
    end
  end

  describe 'hitting the rate limit' do
    before { allow(client).to receive(:fetch_comedy_events).and_raise(Api::RateLimitError, 'Rate limit exceeded') }

    it { expect(stats[:rate_limited]).to eq 1 }
    it { expect(stats[:error]).to eq(class: 'Api::RateLimitError', message: 'Rate limit exceeded') }
  end

  describe 'events that fail to import' do
    let(:events) { Array.new(12) { |i| { 'id' => "e#{i}", 'name' => "Broken Show #{i}" } } }

    before do
      allow(client).to receive(:fetch_comedy_events)
        .and_return('_embedded' => { 'events' => events }, 'page' => { 'totalPages' => 1 })
      allow(Api::TicketmasterTransformer).to receive(:transform_event).and_raise(ActiveRecord::RecordInvalid)
    end

    it 'counts every failure but keeps only a sample of messages' do
      expect(stats[:failed]).to eq 12
      expect(stats[:error_samples].size).to eq Api::Importer::MAX_ERROR_SAMPLES
      expect(stats[:error_samples].first).to start_with 'Broken Show 0: ActiveRecord::RecordInvalid'
    end
  end
end
