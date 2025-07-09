require 'rails_helper'

RSpec.describe Api::GigsController, type: :controller do
  describe 'GET #index' do
    let!(:venue_tokyo) { create(:venue, name: 'Tokyo Comedy Bar', latitude: 35.6762, longitude: 139.6503) }
    let!(:venue_honolulu) { create(:venue, name: 'Honolulu Comedy Club', latitude: 21.3069, longitude: -157.8583) }
    let!(:venue_fiji) { create(:venue, name: 'Fiji Comedy House', latitude: -17.713371, longitude: 178.065032) }
    
    let!(:gig_tokyo) { create(:gig, venue: venue_tokyo) }
    let!(:gig_honolulu) { create(:gig, venue: venue_honolulu) }
    let!(:gig_fiji) { create(:gig, venue: venue_fiji) }

    context 'without bounds parameters' do
      describe 'returning all gigs' do
        before { get :index }
        it { expect(response).to have_http_status(:success) }
        it { expect(JSON.parse(response.body).length).to eq(3) }
      end
    end

    context 'with bounds parameters' do
      context 'when bounds box does not cross antimeridian' do
        describe 'returning gigs within the specified bounds' do
          # Box covering Tokyo area
          before do
            get :index, params: {
              north: 36.0,
              south: 35.0,
              east: 140.0,
              west: 139.0
            }
          end

          it { expect(JSON.parse(response.body).length).to eq(1) }
          it { expect(JSON.parse(response.body).first['venue']['name']).to eq('Tokyo Comedy Bar') }
        end
      end

      context 'when bounds box straddles the antimeridian' do
        describe 'returning gigs from both sides of the antimeridian' do
          # Box covering both Fiji (178°E) and Honolulu (-157°W)
          before do
            get :index, params: {
              north: 25.0,
              south: -20.0,
              east: -150.0,  # 150°W
              west: 175.0    # 175°E
            }
          end

          it { expect(JSON.parse(response.body).length).to eq(2) }
          it { expect(JSON.parse(response.body).map { |gig| gig['venue']['name'] }.sort).to eq(['Fiji Comedy House', 'Honolulu Comedy Club']) }
        end

        describe 'handles bounds crossing antimeridian with wider longitude range' do
          # Box with wider longitude range crossing antimeridian
          before do
            get :index, params: {
              north: 40.0,
              south: -30.0,
              east: -140.0,  # 140°W
              west: 170.0    # 170°E
            }
          end

          it { expect(JSON.parse(response.body).length).to eq(2) }
          it { expect(JSON.parse(response.body).map { |gig| gig['venue']['name'] }.sort).to eq(['Fiji Comedy House', 'Honolulu Comedy Club']) }
        end
      end

      describe 'with invalid bounds parameters' do
        describe 'returns all gigs when bounds params are incomplete' do
          before { get :index, params: { north: 36.0, south: 35.0 } }
          it { expect(JSON.parse(response.body).length).to eq(3) }
        end
      end
    end
  end
end
