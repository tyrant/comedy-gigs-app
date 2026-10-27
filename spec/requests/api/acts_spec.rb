require 'rails_helper'

RSpec.describe 'GET /api/acts' do
  let!(:bill_bailey) { create :act, name: 'Bill Bailey' }
  let!(:billy_connolly) { create :act, name: 'Billy Connolly' }
  let!(:ruby_bill) { create :act, name: 'Ruby Billington' }
  let!(:retired) { create :act, name: 'Bill Hicks' }
  let!(:other) { create :act, name: 'Tig Notaro' }

  before do
    create_list :gig, 2, acts: [ billy_connolly ]
    create :gig, acts: [ bill_bailey ]
    create :gig, acts: [ ruby_bill ]
    create :gig, acts: [ retired ], start_time: 1.month.ago, end_time: 1.month.ago + 2.hours
    create :gig, acts: [ other ], status: 'cancelled'
  end

  let(:names) { response.parsed_body.map { |act| act['name'] } }

  it 'suggests the acts with the most upcoming gigs when there is no query' do
    get '/api/acts'
    expect(names.first(3)).to eq [ 'Billy Connolly', 'Bill Bailey', 'Ruby Billington' ]
    expect(response.parsed_body.first).to include('id' => billy_connolly.id, 'upcoming_gigs' => 2, 'image' => Act::IMAGE_PLACEHOLDER)
  end

  it 'searches names, ranking acts with upcoming gigs and then prefix matches first' do
    get '/api/acts', params: { q: 'bill' }
    expect(names).to eq [ 'Bill Bailey', 'Billy Connolly', 'Ruby Billington', 'Bill Hicks' ]
  end

  it 'treats LIKE wildcards in the query literally' do
    get '/api/acts', params: { q: '%' }
    expect(names).to eq []
  end

  it 'caps the number of results' do
    create_list :act, Api::ActsController::LIMIT, name: 'Billie'
    get '/api/acts', params: { q: 'bill' }
    expect(names.size).to eq Api::ActsController::LIMIT
  end

  it 'returns exactly the requested acts by ID' do
    get '/api/acts', params: { ids: "#{other.id},#{bill_bailey.id}" }
    expect(names).to eq [ 'Bill Bailey', 'Tig Notaro' ]
  end
end
