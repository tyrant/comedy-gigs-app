require 'rails_helper'

RSpec.describe 'GET /api/venues/:venue_id/gigs' do
  include ActiveSupport::Testing::TimeHelpers

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

  it 'names each gig’s sources, so Skiddle’s listings can be credited' do
    later.link_to!('ticketmaster', 'G1')
    later.link_to!('skiddle', '42504161')

    get "/api/venues/#{venue.id}/gigs"
    expect(json['gigs'].map { |gig| gig['sources'] }).to eq [ [], %w[skiddle ticketmaster] ]
  end

  it 'gives a new version once a source is linked to a gig' do
    get "/api/venues/#{venue.id}/gigs"
    etag = response.headers['ETag']

    travel 1.minute do
      later.link_to!('skiddle', '42504161')
      get "/api/venues/#{venue.id}/gigs", headers: { 'If-None-Match' => etag }
    end
    expect(response).to have_http_status :ok
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

  it 'gives each gig’s price range and ticket types, and whether some are nearly gone' do
    later.update!(price_min: 28, price_max: 160, currency: 'NZD', ticket_tiers: [
      { 'name' => 'General Admission', 'price' => 28.0, 'sold_out' => false, 'few_left' => true },
      { 'name' => 'Table for Four', 'price' => 160.0, 'sold_out' => true, 'few_left' => false }
    ])
    sooner.update!(ticket_tiers: [ { 'name' => 'Standard', 'price' => nil, 'sold_out' => false, 'few_left' => true } ])

    get "/api/venues/#{venue.id}/gigs"
    by_id = json['gigs'].index_by { |gig| gig['id'] }

    expect(by_id[later.id]).to include('price' => { 'min' => 28.0, 'max' => 160.0, 'currency' => 'NZD' }, 'few_left' => true)
    expect(by_id[later.id]['tiers'].map { |tier| tier['name'] }).to eq [ 'General Admission', 'Table for Four' ]
    expect(by_id[sooner.id]).to include('price' => nil, 'few_left' => false) # sold out already
  end
end
