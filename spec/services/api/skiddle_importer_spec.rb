require 'rails_helper'

RSpec.describe Api::SkiddleImporter do
  include ActiveSupport::Testing::TimeHelpers

  let(:client) { instance_double(Api::SkiddleClient) }
  let(:importer) { described_class.new }

  before { allow(Api::SkiddleClient).to receive(:new).and_return(client) }

  around { |example| travel_to(Time.utc(2030, 3, 1)) { example.run } }

  let(:with_artist) { skiddle_event(artists: [ skiddle_artist ]) }

  let(:elsewhere) do
    skiddle_event(id: '42504162', name: 'Comedy Lock-In', start: '2030-04-01T19:30:00',
      venue: skiddle_venue(id: '200', name: 'The Glee Club', town: 'Birmingham', lat: '52.4746', lng: '-1.8955'))
  end

  # Pages by offset, as Skiddle does
  def stub_pages(*pages, totalcount: pages.sum(&:size))
    allow(client).to receive(:fetch_comedy_events) do |offset:, to:|
      skiddle_page(pages.fetch(offset / pages.first.size, []), totalcount:)
    end
  end

  describe 'a normal run' do
    before { stub_pages([ with_artist, elsewhere ]) }

    it 'adds a venue, a gig and the listed artists per event' do
      stats = importer.import_events

      expect(stats).to include(total_processed: 2, successful: 2, failed: 0, skipped: 0)
      expect(Venue.pluck(:name)).to contain_exactly('The Laughing Cellar', 'The Glee Club')
      expect(Gig.order(:start_time).map { |gig| [ gig.name, gig.acts.map(&:name) ] }).to eq [
        [ 'Thursday Night Laughs', [ 'Freddy Quinne' ] ],
        [ 'Comedy Lock-In', [] ]
      ]
      expect(Act.sole).to have_attributes(source_ids: { 'skiddle' => [ '123584960' ] },
                                          social_links: { 'spotify' => 'https://open.spotify.com/artist/1Vpy38Qac3HJH8YBRFCRhW' })
    end

    it 'updates rather than duplicates on the next run' do
      importer.import_events
      expect { described_class.new.import_events }.not_to change { [ Venue.count, Gig.count, Act.count ] }
    end

    it 'looks a year ahead' do
      importer.import_events
      expect(client).to have_received(:fetch_comedy_events).with(offset: 0, to: Date.new(2031, 3, 1))
    end
  end

  it 'adds known comedians the title names' do
    urzila = create :act, name: 'Urzila Carlson'
    stub_pages([ skiddle_event(name: 'Urzila Carlson: Fatty On a Yacht') ])

    importer.import_events
    expect(Gig.sole.acts).to eq [ urzila ]
  end

  it 'pages through to the total, importing an event that shows up twice only once' do
    stub_pages([ with_artist ], [ with_artist, elsewhere ], totalcount: 3)

    expect(importer.import_events).to include(total_processed: 2, successful: 2)
    expect(Gig.count).to eq 2
  end

  describe 'a show Ticketmaster already lists' do
    let!(:venue) do
      create :venue, name: 'The Laughing Cellar', city: 'Leeds', latitude: 53.7998, longitude: -1.5491,
                     address: '12 Call Lane', sources: { 'ticketmaster' => 'KovZ1' }
    end
    let!(:gig) do
      create :gig, name: 'Thursday Night Laughs', venue:, start_time: Time.utc(2030, 3, 7, 20), end_time: Time.utc(2030, 3, 7, 22),
                   ticket_url: 'https://www.ticketmaster.co.uk/event/1', sources: { 'ticketmaster' => 'G5v1' },
                   description: 'Ticketmaster’s blurb' # so there's nothing blank for Skiddle to fill
    end

    before { stub_pages([ skiddle_event ]) }

    it 'links to it without overwriting Ticketmaster’s details' do
      importer.import_events

      expect(venue.reload.source_ids).to eq('ticketmaster' => [ 'KovZ1' ], 'skiddle' => [ '137901' ])
      expect(gig.reload).to have_attributes(ticket_url: 'https://www.ticketmaster.co.uk/event/1',
                                            source_ids: { 'ticketmaster' => [ 'G5v1' ], 'skiddle' => [ '42504161' ] })
      expect(Gig.count).to eq 1
    end

    it 'touches it, so cached listings pick up the Skiddle credit' do
      travel 1.hour
      expect { importer.import_events }.to change { gig.reload.updated_at }
    end
  end

  it 'records a fatal API error for the rake task to report' do
    allow(client).to receive(:fetch_comedy_events).and_raise(Api::AuthenticationError, 'Invalid Skiddle API key')

    expect(importer.import_events[:error]).to eq(class: 'Api::AuthenticationError', message: 'Invalid Skiddle API key')
  end
end
