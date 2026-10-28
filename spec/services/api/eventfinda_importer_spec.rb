require 'rails_helper'

RSpec.describe Api::EventfindaImporter do
  include ActiveSupport::Testing::TimeHelpers

  let(:client) { instance_double(Api::EventfindaClient) }
  let(:importer) { described_class.new }

  before { allow(Api::EventfindaClient).to receive(:new).and_return(client) }

  around { |example| travel_to(Time.utc(2030, 3, 1)) { example.run } }

  let(:weekly_show) do
    eventfinda_event(id: 1, name: 'Late Night Laughs', sessions: [
      eventfinda_session(id: 11, start: '2030-03-07 19:30:00'),
      eventfinda_session(id: 12, start: '2030-03-14 19:30:00')
    ])
  end

  let(:one_off) do
    eventfinda_event(id: 2, name: 'Kiwi Comedy Gala',
      location: eventfinda_location(id: 502, name: 'Civic Theatre', summary: 'Civic Theatre, CBD, Auckland', lat: -36.8519, lng: 174.7637),
      sessions: [ eventfinda_session(id: 21, start: '2030-04-01 20:00:00') ])
  end

  def stub_pages(*pages)
    allow(client).to receive(:fetch_comedy_events) do |offset:|
      pages.fetch(offset / Api::EventfindaClient::PAGE_SIZE)
    end
  end

  describe 'a normal run' do
    before { stub_pages(eventfinda_page([ weekly_show, one_off ])) }

    it 'adds a venue per location and a gig per session' do
      stats = importer.import_events

      expect(stats).to include(total_processed: 2, successful: 2, failed: 0, skipped: 0, gigs: 3)
      expect(Venue.pluck(:name)).to contain_exactly('The Fringe Bar', 'Civic Theatre')
      expect(Gig.order(:start_time).pluck(:name, :local_date)).to eq [
        [ 'Late Night Laughs', Date.new(2030, 3, 7) ],
        [ 'Late Night Laughs', Date.new(2030, 3, 14) ],
        [ 'Kiwi Comedy Gala', Date.new(2030, 4, 1) ]
      ]
      expect(Gig.all.map { |gig| gig.acts.size }).to all(eq 0)
    end

    it 'updates rather than duplicates on the next run' do
      importer.import_events
      expect { described_class.new.import_events }.not_to change { [ Venue.count, Gig.count ] }
    end
  end

  it 'pages by offset until it has the reported count, however short the pages' do
    stub_pages(eventfinda_page([ weekly_show ], count: 25), eventfinda_page([ one_off ], count: 25))

    expect(importer.import_events).to include(total_processed: 2, gigs: 3)
    expect(client).to have_received(:fetch_comedy_events).twice
  end

  it 'merges a show listed twice into one gig per session' do
    relisted = weekly_show.merge('id' => 3, 'sessions' => { 'sessions' => [
      eventfinda_session(id: 31, start: '2030-03-07 19:30:00'), eventfinda_session(id: 32, start: '2030-03-14 19:30:00')
    ] })
    stub_pages(eventfinda_page([ weekly_show, relisted ]))

    importer.import_events
    expect(Gig.count).to eq 2
  end

  describe 'a show Ticketmaster already lists' do
    let(:act) { create :act, name: 'Rhys Mathewson' }
    let!(:venue) do
      create :venue, name: 'The Fringe Bar', latitude: -41.2935, longitude: 174.7787,
                     address: '26 Cuba St', external_ids: { 'ticketmaster' => 'KovZ1' }
    end
    let!(:gig) do
      create :gig, name: 'Late Night Laughs', venue:, acts: [ act ], start_time: Time.utc(2030, 3, 7, 6, 30), end_time: nil,
                   ticket_url: 'https://www.ticketmaster.co.nz/event/1', external_ids: { 'ticketmaster' => 'G5v1' }
    end

    before { stub_pages(eventfinda_page([ weekly_show ])) }

    it 'links to it without overwriting Ticketmaster’s details or lineup' do
      importer.import_events

      expect(venue.reload).to have_attributes(address: '26 Cuba St', external_ids: { 'ticketmaster' => 'KovZ1', 'eventfinda' => '501' })
      expect(gig.reload).to have_attributes(ticket_url: 'https://www.ticketmaster.co.nz/event/1', acts: [ act ],
                                            external_ids: { 'ticketmaster' => 'G5v1', 'eventfinda' => '11' })
      expect(gig.description).to eq 'Stand-up & sketches. R18' # blank before, so filled in
      expect(Gig.count).to eq 2 # the other session is new
    end
  end

  describe 'trouble' do
    it 'counts an event that fails and carries on' do
      broken = weekly_show.merge('name' => 'Broken Show')
      allow(Venue).to receive(:from_existing).and_call_original
      allow(Venue).to receive(:from_existing).with(hash_including(name: 'The Fringe Bar'), 'eventfinda').and_raise(ActiveRecord::RecordInvalid)
      stub_pages(eventfinda_page([ broken, one_off ]))

      stats = importer.import_events
      expect(stats).to include(successful: 1, failed: 1)
      expect(stats[:error_samples].first).to start_with 'Broken Show: ActiveRecord::RecordInvalid'
    end

    it 'records a fatal API error for the rake task to report' do
      allow(client).to receive(:fetch_comedy_events).and_raise(Api::AuthenticationError, 'Invalid Eventfinda API credentials')

      expect(importer.import_events[:error]).to eq(class: 'Api::AuthenticationError', message: 'Invalid Eventfinda API credentials')
    end

    it 'counts a rate limit it couldn’t wait out' do
      allow(client).to receive(:fetch_comedy_events).and_raise(Api::RateLimitError, 'Eventfinda rate limit exceeded')

      expect(importer.import_events).to include(rate_limited: 1, error: hash_including(class: 'Api::RateLimitError'))
    end
  end
end
