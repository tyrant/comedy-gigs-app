require 'rails_helper'

RSpec.describe 'GET /api/venues/:venue_id/gigs' do
  let(:venue) { create :venue, timezone: 'Pacific/Auckland', images: { 'medium' => 'https://example.com/venue.jpg' }, website: 'https://example.com' }
  let(:act_a) { create :act, name: 'Aardvark', images: { 'thumb' => 'https://example.com/a.jpg' } }
  let(:act_b) { create :act, name: 'Badger' }

  let!(:later) { create :gig, venue:, name: ' Later Show ', start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours, acts: [ act_b, act_a ] }
  let!(:sooner) { create :gig, venue:, start_time: 1.day.from_now, end_time: 1.day.from_now + 2.hours, acts: [ act_b ], status: 'sold_out' }
  let!(:cancelled) { create :gig, venue:, status: 'cancelled' }
  let!(:elsewhere) { create :gig }

  let(:json) { response.parsed_body }

  it "returns the venue and its gigs in date order, without cancellations" do
    get "/api/venues/#{venue.id}/gigs"

    expect(json['venue']).to include('id' => venue.id, 'name' => venue.name, 'timezone' => 'Pacific/Auckland',
                                     'image' => 'https://example.com/venue.jpg', 'website' => 'https://example.com')
    expect(json['gigs'].map { |gig| gig['id'] }).to eq [ sooner.id, later.id ]
    expect(json['gigs'].first).to include('status' => 'sold_out', 'ticket_url' => sooner.ticket_url)
  end

  it 'lists each gig’s acts by name, with thumbnails' do
    get "/api/venues/#{venue.id}/gigs"

    expect(json['gigs'].last['name']).to eq 'Later Show'
    expect(json['gigs'].last['acts']).to eq [
      { 'id' => act_a.id, 'name' => 'Aardvark', 'image' => 'https://example.com/a.jpg' },
      { 'id' => act_b.id, 'name' => 'Badger', 'image' => Act::IMAGE_PLACEHOLDER }
    ]
  end

  it 'applies the filters' do
    get "/api/venues/#{venue.id}/gigs", params: { act_ids: act_a.id.to_s }
    expect(json['gigs'].map { |gig| gig['id'] }).to eq [ later.id ]
  end

  it 'answers a repeat request with 304 Not Modified' do
    get "/api/venues/#{venue.id}/gigs"
    get "/api/venues/#{venue.id}/gigs", headers: { 'If-None-Match' => response.headers['ETag'] }
    expect(response).to have_http_status :not_modified
  end

  it 'is a 404 for an unknown venue' do
    get '/api/venues/0/gigs'
    expect(response).to have_http_status :not_found
  end
end
