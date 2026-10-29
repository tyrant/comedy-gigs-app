require 'rails_helper'

RSpec.describe Api::EventfindaTransformer do
  let(:now) { Time.utc(2030, 3, 1) }

  subject(:result) { described_class.transform_event(event, now:) }

  describe 'the venue' do
    let(:event) { eventfinda_event }

    it 'comes from the event location, in New Zealand' do
      expect(result[:venue]).to include(
        name: 'The Fringe Bar',
        address: '26 Cuba Street, Te Aro, Wellington',
        city: 'Wellington',
        country: 'New Zealand',
        latitude: -41.2935,
        longitude: 174.7787,
        timezone: 'Pacific/Auckland',
        external_ids: { 'eventfinda' => '501' },
        website: 'https://www.eventfinda.co.nz/venue/the-fringe-bar'
      )
    end

    it 'uses the 650x280 photo' do
      expect(result[:venue][:images]).to eq('medium' => 'https://cdn.eventfinda.co.nz/uploads/locations/transformed/77-7.jpg')
    end

    context 'when the location only has Eventfinda’s stock photo' do
      let(:event) { eventfinda_event(location: eventfinda_location(image_id: nil)) }

      it { expect(result[:venue][:images]).to eq({}) }
    end

    {
      'The Fringe Bar, Wellington' => 'Wellington',          # a big city is its own region
      'The Fringe Bar, Kingsland, Auckland' => 'Auckland',   # ...with suburbs before it
      'The Fringe Bar, Rotorua, Bay of Plenty' => 'Rotorua'  # elsewhere the town comes before the region
    }.each do |summary, city|
      it "finds #{city} in “#{summary}”" do
        event = eventfinda_event(location: eventfinda_location(summary:))
        expect(described_class.transform_event(event, now:)[:venue][:city]).to eq city
      end
    end
  end

  describe 'the gigs' do
    let(:event) do
      eventfinda_event(sessions: [
        eventfinda_session(id: 1, start: '2030-02-20 19:30:00'),                     # long gone
        eventfinda_session(id: 2, start: '2030-03-01 08:00:00'),                     # earlier today in NZ
        eventfinda_session(id: 3, start: '2030-03-07 19:30:00', finish: '2030-03-07 21:00:00'),
        eventfinda_session(id: 4, start: '2030-03-14 19:30:00', finish: '2030-03-14 19:30:00')
      ])
    end

    it 'makes one per upcoming session, skipping those well past' do
      expect(result[:gigs].map { |gig| gig[:external_ids] }).to eq [ { 'eventfinda' => '2' }, { 'eventfinda' => '3' }, { 'eventfinda' => '4' } ]
    end

    it 'reads session times in the venue’s time zone' do
      gig = result[:gigs].second
      expect(gig[:start_time]).to eq Time.utc(2030, 3, 7, 6, 30) # 7:30pm NZDT
      expect(gig[:end_time]).to eq Time.utc(2030, 3, 7, 8)
    end

    it 'drops an end time that isn’t after the start' do
      expect(result[:gigs].last[:end_time]).to be_nil
    end

    it 'links to the Eventfinda event page and keeps the description as plain text' do
      expect(result[:gigs].first).to include(
        name: 'Late Night Laughs',
        ticket_url: 'https://www.eventfinda.co.nz/2030/late-night-laughs/wellington',
        description: 'Stand-up & sketches. R18'
      )
    end
  end

  describe 'status' do
    let(:sessions) { [ eventfinda_session(id: 1, start: '2030-03-07 19:30:00'), eventfinda_session(id: 2, start: '2030-03-08 19:30:00', cancelled: true) ] }

    it 'cancels just the cancelled sessions' do
      gigs = described_class.transform_event(eventfinda_event(sessions:), now:)[:gigs]
      expect(gigs.map { |gig| gig[:status] }).to eq %w[scheduled cancelled]
    end

    it 'cancels every session of a cancelled event' do
      gigs = described_class.transform_event(eventfinda_event(sessions:, is_cancelled: true), now:)[:gigs]
      expect(gigs.map { |gig| gig[:status] }).to eq %w[cancelled cancelled]
    end

    it 'marks a sold-out event' do
      gigs = described_class.transform_event(eventfinda_event(sessions: sessions.first(1), is_sold_out: true), now:)[:gigs]
      expect(gigs.map { |gig| gig[:status] }).to eq %w[sold_out]
    end
  end

  describe 'events that can’t be listed' do
    it 'skips one without a location' do
      expect(described_class.transform_event(eventfinda_event(location: nil), now:)).to be_nil
    end

    it 'skips one without coordinates' do
      location = eventfinda_location.merge('point' => nil)
      expect(described_class.transform_event(eventfinda_event(location:, point: nil), now:)).to be_nil
    end

    it 'skips one whose sessions are all over' do
      event = eventfinda_event(sessions: [ eventfinda_session(id: 1, start: '2030-01-01 19:30:00') ])
      expect(described_class.transform_event(event, now:)).to be_nil
    end
  end

  describe 'prices' do
    def ticket(name, price, addon: false, sold_out: false, few_left: false)
      { 'name' => name, 'price' => price, 'is_addon' => addon, 'is_sold_out' => sold_out, 'is_limited_remaining' => few_left }
    end

    def gig_for(session_tickets: nil, ticket_types: nil, **attrs)
      session = eventfinda_session(id: 1, start: '2030-03-07 19:30:00')
      session['session_tickets'] = { 'session_tickets' => session_tickets } if session_tickets
      event = eventfinda_event(sessions: [ session ], **attrs)
      event['ticket_types'] = { 'ticket_types' => ticket_types } if ticket_types
      described_class.transform_event(event, now:)[:gigs].first
    end

    it 'lists the session’s ticket types, leaving out add-ons, with the range they span' do
      gig = gig_for(session_tickets: [ ticket('General Admission', '28.00', few_left: true), ticket('Table for Four', '160.00', sold_out: true),
                                       ticket('Parking', '10.00', addon: true) ])

      expect(gig[:ticket_tiers]).to eq [
        { 'name' => 'General Admission', 'price' => 28.0, 'sold_out' => false, 'few_left' => true },
        { 'name' => 'Table for Four', 'price' => 160.0, 'sold_out' => true, 'few_left' => false }
      ]
      expect(gig).to include(price_min: 28.0, price_max: 160.0, currency: 'NZD')
    end

    it 'falls back on the event’s ticket types' do
      expect(gig_for(ticket_types: [ ticket('Single Admit', '25.00') ])).to include(price_min: 25.0, price_max: 25.0)
    end

    it 'makes a free event free' do
      expect(gig_for(is_free: true)).to include(price_min: 0.0, price_max: 0.0)
    end

    it 'gives no price keys without prices' do
      expect(gig_for.keys).not_to include(:price_min, :ticket_tiers)
    end
  end
end
