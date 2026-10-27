require 'rails_helper'

RSpec.describe 'GET /api/venues' do
  let!(:tokyo) { create :venue, name: 'Tokyo Club', latitude: 35.6762, longitude: 139.6503 }
  let!(:fiji) { create :venue, name: 'Fiji Club', latitude: -17.713371, longitude: 178.065032 }
  let!(:act) { create :act }

  before do
    create_list :gig, 2, venue: tokyo, acts: [ act ]
    create :gig, venue: fiji
    create :gig, venue: fiji, status: 'cancelled'
  end

  let(:json) { response.parsed_body }

  it 'lists every venue with matching gigs, worldwide, with its gig count' do
    get '/api/venues'

    expect(json).to contain_exactly(
      { 'id' => tokyo.id, 'name' => 'Tokyo Club', 'lat' => 35.6762, 'lng' => 139.6503, 'gigs' => 2 },
      { 'id' => fiji.id, 'name' => 'Fiji Club', 'lat' => -17.713371, 'lng' => 178.065032, 'gigs' => 1 }
    )
  end

  it 'applies the act and date filters' do
    get '/api/venues', params: { act_ids: act.id.to_s }
    expect(response.parsed_body.map { |venue| venue['id'] }).to eq [ tokyo.id ]

    get '/api/venues', params: { start_date: 1.week.from_now.to_date.to_s }
    expect(response.parsed_body).to eq []
  end

  it 'leaves out venues without coordinates' do
    tokyo.update_columns(latitude: nil, longitude: nil)
    get '/api/venues'
    expect(json.map { |venue| venue['id'] }).to eq [ fiji.id ]
  end

  describe 'caching' do
    before { get '/api/venues' }

    let(:etag) { response.headers['ETag'] }

    it { expect(response.headers['Cache-Control']).to include 'max-age=0', 'public', 'must-revalidate' }

    it 'answers a repeat request with 304 Not Modified' do
      get '/api/venues', headers: { 'If-None-Match' => etag }
      expect(response).to have_http_status :not_modified
    end

    it 'changes the ETag when the filters change' do
      get '/api/venues', params: { act_ids: act.id.to_s }, headers: { 'If-None-Match' => etag }
      expect(response).to have_http_status :ok
    end

    it 'changes the ETag when a gig is removed' do
      Gig.where(venue: fiji).delete_all
      get '/api/venues', headers: { 'If-None-Match' => etag }
      expect(response).to have_http_status :ok
    end
  end
end
