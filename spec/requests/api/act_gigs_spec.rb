require 'rails_helper'

RSpec.describe 'GET /api/acts/:act_id/gigs' do
  let(:act) do
    create :act, name: 'Rose Matafeo', description: 'NZ comedian', images: { 'large' => 'https://example.com/rose.jpg' },
                 social_links: { 'twitter' => '@rosematafeo' }
  end
  let(:other_act) { create :act }
  let(:venue) { create :venue, name: 'San Fran', city: 'Wellington', latitude: -41.29, longitude: 174.78, timezone: 'Pacific/Auckland' }

  let!(:later) { create :gig, acts: [ act, other_act ], venue:, start_time: 3.weeks.from_now, end_time: nil }
  let!(:sooner) { create :gig, acts: [ act ], start_time: 1.week.from_now, end_time: nil }
  let!(:cancelled) { create :gig, acts: [ act ], status: 'cancelled' }
  let!(:unmapped) { create :gig, acts: [ act ], venue: create(:venue).tap { |unplaced| unplaced.update_columns(latitude: nil, longitude: nil) } }
  let!(:someone_else) { create :gig, acts: [ other_act ] }

  let(:json) { response.parsed_body }

  it 'returns the act and its mapped gigs in date order, with their venues' do
    get "/api/acts/#{act.id}/gigs"

    expect(json['act']).to eq('id' => act.id, 'name' => 'Rose Matafeo', 'image' => 'https://example.com/rose.jpg',
                              'description' => 'NZ comedian', 'description_url' => nil,
                              'links' => [ { 'kind' => 'twitter', 'url' => 'https://x.com/rosematafeo' } ])
    expect(json['gigs'].map { |gig| gig['id'] }).to eq [ sooner.id, later.id ]
    expect(json['gigs'].last['venue']).to eq('id' => venue.id, 'name' => 'San Fran', 'city' => 'Wellington',
                                             'timezone' => 'Pacific/Auckland', 'lat' => -41.29, 'lng' => 174.78)
  end

  it 'applies the dates but not the act filter' do
    get "/api/acts/#{act.id}/gigs", params: { end_date: 2.weeks.from_now.to_date.iso8601, act_ids: other_act.id.to_s }
    expect(json['gigs'].map { |gig| gig['id'] }).to eq [ sooner.id ]
  end

  it 'falls back to the Wikipedia bio, with a link to credit it' do
    act.update!(description: nil, bio: 'Rose Matafeo is a New Zealand comedian.', bio_url: 'https://en.wikipedia.org/wiki/Rose_Matafeo')
    get "/api/acts/#{act.id}/gigs"

    expect(json['act']).to include('description' => 'Rose Matafeo is a New Zealand comedian.',
                                   'description_url' => 'https://en.wikipedia.org/wiki/Rose_Matafeo')
  end

    it 'has no banner without a photo' do
    get "/api/acts/#{other_act.id}/gigs"
    expect(json['act']['image']).to be_nil
  end

  it 'is a 404 for an unknown act' do
    get '/api/acts/0/gigs'
    expect(response).to have_http_status :not_found
  end
end
