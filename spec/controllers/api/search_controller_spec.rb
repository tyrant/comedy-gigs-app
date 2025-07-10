require 'rails_helper'

RSpec.describe Api::SearchController, type: :controller do
  describe 'GET #index' do
    let!(:venue) { create(:venue, name: 'Comedy Club', city: 'New York') }
    let!(:act) { create(:act, name: 'John Comedian', description: 'Hilarious stand-up') }
    let!(:gig) do
      create(:gig, 
        name: 'Comedy Night', 
        venue: venue, 
        start_time: 1.day.from_now,
        description: 'A night of laughs'
      ).tap { |g| g.acts << act }
    end
    
    before do
      # Add image data to act and venue
      act.update(images: { 'large' => 'https://example.com/act.jpg' })
      venue.update(images: { 'large' => 'https://example.com/venue.jpg' })
    end

    context 'with no parameters' do
      it 'returns all upcoming gigs, venues, and acts' do
        get :index
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to be > 0
        expect(json_response.map { |r| r['type'] }).to include('gig', 'venue', 'act')
      end
    end
    
    context 'with type parameter' do
      it 'returns only gigs when type=gigs' do
        get :index, params: { type: 'gigs' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to be > 0
        expect(json_response.map { |r| r['type'] }.uniq).to eq(['gig'])
      end
      
      it 'returns only venues when type=venues' do
        get :index, params: { type: 'venues' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to be > 0
        expect(json_response.map { |r| r['type'] }.uniq).to eq(['venue'])
      end
      
      it 'returns only acts when type=acts' do
        get :index, params: { type: 'acts' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to be > 0
        expect(json_response.map { |r| r['type'] }.uniq).to eq(['act'])
      end
    end
    
    context 'with query parameter' do
      it 'returns matching gigs' do
        get :index, params: { query: 'Comedy', type: 'gigs' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to be > 0
        expect(json_response.first['name']).to include('Comedy')
      end
      
      it 'returns matching venues' do
        get :index, params: { query: 'Comedy', type: 'venues' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to be > 0
        expect(json_response.first['name']).to include('Comedy')
      end
      
      it 'returns matching acts' do
        get :index, params: { query: 'Comedian', type: 'acts' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to be > 0
        expect(json_response.first['name']).to include('Comedian')
      end
    end
    
    context 'with date parameters' do
      let!(:past_gig) do
        create(:gig, 
          name: 'Past Comedy Night', 
          venue: venue, 
          start_time: 1.day.ago
        ).tap { |g| g.acts << act }
      end
      
      let!(:future_gig) do
        create(:gig, 
          name: 'Future Comedy Night', 
          venue: venue, 
          start_time: 30.days.from_now
        ).tap { |g| g.acts << act }
      end
      
      it 'returns gigs within the date range' do
        get :index, params: { 
          type: 'gigs',
          start_date: Date.today.to_s,
          end_date: 7.days.from_now.to_date.to_s
        }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to eq(1)
        expect(json_response.first['name']).to eq('Comedy Night')
      end
      
      it 'returns acts with gigs in the date range' do
        get :index, params: { 
          type: 'acts',
          start_date: 20.days.from_now.to_date.to_s,
          end_date: 40.days.from_now.to_date.to_s
        }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.size).to eq(1)
        expect(json_response.first['name']).to eq('John Comedian')
        expect(json_response.first['gigs'].map { |g| g['name'] }).to include('Future Comedy Night')
      end
    end
    
    context 'with image data' do
      it 'includes primary_image_url for venues' do
        get :index, params: { type: 'venues' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.first['primary_image_url']).to eq('https://example.com/venue.jpg')
        expect(json_response.first['images']).to be_present
      end
      
      it 'includes primary_image_url for acts' do
        get :index, params: { type: 'acts' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response.first['primary_image_url']).to eq('https://example.com/act.jpg')
        expect(json_response.first['images']).to be_present
      end
    end
  end
end
