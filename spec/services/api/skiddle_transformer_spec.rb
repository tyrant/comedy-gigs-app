require 'rails_helper'

RSpec.describe Api::SkiddleTransformer do
  let(:now) { Time.utc(2030, 3, 1) }
  let(:event) { skiddle_event }

  subject(:result) { described_class.transform_event(event, now:) }

  it 'places the venue in the UK, with its address' do
    expect(result[:venue]).to eq(
      name: 'The Laughing Cellar',
      address: '12 Call Lane, Leeds, LS1 6DT',
      city: 'Leeds',
      country: 'Great Britain',
      latitude: 53.7997,
      longitude: -1.5492,
      timezone: 'Europe/London',
      external_ids: { 'skiddle' => '137901' }
    )
  end

  it 'makes a gig that links to the event’s Skiddle page' do
    expect(result[:gig]).to include(
      name: 'Thursday Night Laughs',
      description: 'Three of the best acts on the circuit!',
      ticket_url: 'https://www.skiddle.com/whats-on/Leeds/The-Laughing-Cellar/thursday-night-laughs/42504161/',
      status: 'scheduled',
      external_ids: { 'skiddle' => '42504161' }
    )
  end

  describe 'times' do
    it 'reads winter times as given' do
      expect(result[:gig][:start_time]).to eq Time.utc(2030, 3, 7, 20, 0)
      expect(result[:gig][:end_time]).to eq Time.utc(2030, 3, 7, 22, 15)
    end

    context 'in British Summer Time' do
      # Skiddle still says +00:00, but 20:00 is the UK wall-clock time
      let(:event) { skiddle_event(start: '2030-06-07T20:00:00', finish: '2030-06-07T22:15:00') }

      it 'reads them as London time' do
        expect(result[:gig][:start_time]).to eq Time.utc(2030, 6, 7, 19, 0)
        expect(result[:gig][:start_time].in_time_zone('Europe/London').strftime('%H:%M')).to eq '20:00'
      end
    end

    context 'when the end isn’t after the start' do
      let(:event) { skiddle_event(finish: '2030-03-07T20:00:00') }

      it { expect(result[:gig][:end_time]).to be_nil }
    end

    context 'when there’s no end' do
      let(:event) { skiddle_event(finish: nil) }

      it { expect(result[:gig][:end_time]).to be_nil }
    end
  end

  context 'when the event is cancelled' do
    let(:event) { skiddle_event(cancelled: true) }

    it { expect(result[:gig][:status]).to eq 'cancelled' }
  end

  describe 'artists' do
    let(:event) { skiddle_event(artists: [ skiddle_artist, skiddle_artist, skiddle_artist(id: '9', name: 'Nobody Spotify', spotify: nil) ]) }

    it 'become acts once each, with their photo and Spotify page' do
      expect(result[:acts]).to eq [
        {
          name: 'Freddy Quinne',
          images: { 'large' => 'https://d1mdxzfl9p8pzo.cloudfront.net/0/123584960_1_1024.jpg' },
          social_links: { 'spotify' => 'https://open.spotify.com/artist/1Vpy38Qac3HJH8YBRFCRhW' },
          external_ids: { 'skiddle' => '123584960' }
        },
        {
          name: 'Nobody Spotify',
          images: { 'large' => 'https://d1mdxzfl9p8pzo.cloudfront.net/0/9_1_1024.jpg' },
          social_links: {},
          external_ids: { 'skiddle' => '9' }
        }
      ]
    end
  end

  describe 'events it can’t use' do
    it 'skips a venue Skiddle hasn’t placed' do
      expect(described_class.transform_event(skiddle_event(venue: skiddle_venue(lat: '0', lng: '0')), now:)).to be_nil
    end

    it 'skips a show that’s over' do
      expect(described_class.transform_event(skiddle_event(start: '2030-02-27T20:00:00'), now:)).to be_nil
    end

    it 'keeps tonight’s show a while after it starts' do
      expect(described_class.transform_event(event, now: Time.utc(2030, 3, 7, 23))).to be_present
    end
  end
end
