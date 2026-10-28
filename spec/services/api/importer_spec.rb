require 'rails_helper'

RSpec.describe Api::Importer do
  def importer_for(source)
    Class.new(described_class) do
      define_method(:initialize) { @source = source; super() }
      public :upsert_venue
    end.new
  end

  let(:importer) { importer_for('ticketmaster') }

  before do
    allow(VenueLocator::RATE_LIMITER).to receive(:with_rate_limit).and_yield
    Geocoder::Lookup::Test.set_default_stub([])
  end
  after { Geocoder::Lookup::Test.reset }

  let(:unplaced) do
    { name: 'Big Belly Comedy', address: 'Unit 6 & 7, 30 Stamford St', city: 'London', country: 'United Kingdom',
      latitude: nil, longitude: nil, timezone: 'Europe/London', external_ids: { 'ticketmaster' => 'KovZ9' },
      postcode: 'SE1 9LQ', country_code: 'GB' }
  end

  describe 'a venue that arrives without coordinates' do
    it 'is placed from its address' do
      Geocoder::Lookup::Test.add_stub('30 Stamford St, London, SE1 9LQ', [ { 'latitude' => 51.5076, 'longitude' => -0.108, 'place_rank' => 30, 'address' => 'Stamford St, London' } ])

      venue = importer.upsert_venue(unplaced)
      expect(venue).to be_persisted
      expect([ venue.latitude.to_f, venue.longitude.to_f ]).to eq [ 51.5076, -0.108 ]
    end

    it 'keeps the coordinates found on an earlier night, without looking again' do
      create :venue, latitude: 51.5076, longitude: -0.108, sources: { 'ticketmaster' => 'KovZ9' }
      allow(Geocoder).to receive(:search)

      expect(importer.upsert_venue(unplaced).latitude.to_f).to eq 51.5076
      expect(Geocoder).not_to have_received(:search)
    end

    it 'fails to save when it can’t be placed, as before' do
      expect { importer.upsert_venue(unplaced) }.to raise_error(ActiveRecord::RecordInvalid, /Latitude can't be blank/)
    end
  end

  describe 'two sources describing one venue' do
    let!(:venue) do
      create :venue, name: 'The Fringe Bar', address: '26 Cuba St', description: nil, latitude: -41.2935, longitude: 174.7787,
                     sources: { 'ticketmaster' => 'KovZ1' }
    end
    let(:from_eventfinda) do
      { name: 'The Fringe Bar', address: '26 Cuba Street, Te Aro, Wellington', city: 'Wellington', country: 'New Zealand',
        description: 'Upstairs on Cuba', latitude: -41.2935, longitude: 174.7787, external_ids: { 'eventfinda' => '501' } }
    end

    it 'lets the lower-priority source fill blanks only' do
      importer_for('eventfinda').upsert_venue(from_eventfinda)

      expect(venue.reload).to have_attributes(address: '26 Cuba St', description: 'Upstairs on Cuba',
                                              source_ids: { 'ticketmaster' => [ 'KovZ1' ], 'eventfinda' => [ '501' ] })
    end

    it 'lets the higher-priority source overwrite' do
      venue.source_links.delete_all
      venue.link_to!('eventfinda', '501')
      importer.upsert_venue(from_eventfinda.merge(external_ids: { 'ticketmaster' => 'KovZ1' }))

      expect(venue.reload.address).to eq '26 Cuba Street, Te Aro, Wellington'
    end
  end

  describe 'gigs listed more than once' do
    def gig_importer(source)
      Class.new(described_class) do
        define_method(:initialize) { @source = source; super() }
        public :upsert_gig
      end.new
    end

    let(:venue) { create :venue }
    let(:start) { Time.utc(2030, 1, 23, 4) }
    let(:show) { { name: 'Nikki Glaser: The Vegas Residency', start_time: start, venue:, ticket_url: 'https://tm.example/show', external_ids: { 'ticketmaster' => 'SHOW' } } }
    let(:package) { { name: 'Nikki Glaser | Official Caesars Ticket + Hotel Packages', start_time: start, venue:, ticket_url: 'https://tm.example/package', external_ids: { 'ticketmaster' => 'PKG' } } }

    it 'names the gig after the show, whichever listing comes first, night after night' do
      importer = gig_importer('ticketmaster')
      nikki = create(:act, name: 'Nikki Glaser') # both listings name her, which is how they match
      2.times do
        importer.upsert_gig(package.merge(acts: [ nikki ]))
        importer.upsert_gig(show.merge(acts: [ nikki ]))
      end

      expect(Gig.count).to eq 1
      expect(Gig.first).to have_attributes(name: 'Nikki Glaser: The Vegas Residency', ticket_url: 'https://tm.example/show',
                                           source_ids: { 'ticketmaster' => %w[PKG SHOW] })
    end

    it 'keeps both IDs of a show Eventfinda lists twice, so neither run starts a new gig' do
      importer = gig_importer('eventfinda')
      listing = { name: 'Dropout Comedy', start_time: start, venue:, ticket_url: 'https://ef.example/1' }
      2.times do
        importer.upsert_gig(listing.merge(external_ids: { 'eventfinda' => '1' }))
        importer.upsert_gig(listing.merge(ticket_url: 'https://ef.example/2', external_ids: { 'eventfinda' => '2' }))
      end

      expect(Gig.count).to eq 1
      expect(Gig.first).to have_attributes(ticket_url: 'https://ef.example/1', source_ids: { 'eventfinda' => %w[1 2] })
    end
  end
end
