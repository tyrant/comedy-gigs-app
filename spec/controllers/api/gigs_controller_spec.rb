require 'rails_helper'

RSpec.describe Api::GigsController, type: :controller do
  describe 'GET #index' do
    let(:tokyo_name) { Faker::Sports::Basketball.coach }
    let!(:venue_tokyo) { create :venue, name: tokyo_name,
                                        latitude: 35.6762,
                                        longitude: 139.6503 }
    let(:honolulu_name) { Faker::Sports::Chess.opening }
    let!(:venue_honolulu) { create :venue, name: honolulu_name,
                                           latitude: 21.3069,
                                           longitude: -157.8583 }
    let(:fiji_name) { Faker::Sports::Football.team }
    let!(:venue_fiji) { create :venue, name: fiji_name,
                                       latitude: -17.713371,
                                       longitude: 178.065032 }

    let!(:gig_tokyo) { create :gig, venue: venue_tokyo }
    let!(:gig_honolulu) { create :gig, venue: venue_honolulu }
    let!(:gig_fiji) { create :gig, venue: venue_fiji }

    context 'without bounds parameters' do
      describe 'returning all gigs' do
        before { get :index }
        it { expect(response).to have_http_status(:success) }
        it { expect(JSON.parse(response.body).length).to eq 3 }
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

          it { expect(JSON.parse(response.body).length).to eq 1 }
          it { expect(JSON.parse(response.body).first['venue']['name']).to eq tokyo_name }
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

          it { expect(JSON.parse(response.body).length).to eq 2 }
          it { expect(JSON.parse(response.body).map { |gig| gig['venue']['name'] })
                 .to match_array [ fiji_name, honolulu_name ] }
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

          it { expect(JSON.parse(response.body).length).to eq 2 }
          it { expect(JSON.parse(response.body).map { |gig| gig['venue']['name'] })
                 .to match_array [ fiji_name, honolulu_name ] }
        end
      end

      describe 'with invalid bounds parameters' do
        describe 'returns all gigs when bounds params are incomplete' do
          before { get :index, params: { north: 36.0, south: 35.0 } }
          it { expect(JSON.parse(response.body).length).to eq 3 }
        end
      end
    end

    context 'with act_ids parameter' do
      let(:act1_name) { Faker::Movies::BackToTheFuture.character }
      let(:act2_name) { Faker::Movies::Ghostbusters.character }
      let(:act3_name) { Faker::Games::SuperSmashBros.fighter }
      let!(:act1) { create :act, name: act1_name }
      let!(:act2) { create :act, name: act2_name }
      let!(:act3) { create :act, name: act3_name }

      # Update existing gigs to have acts
      before do
        gig_tokyo.acts = [ act1 ]
        gig_tokyo.save!
        gig_honolulu.acts = [ act2 ]
        gig_honolulu.save!
        gig_fiji.acts = [ act1, act3 ]
        gig_fiji.save!
      end

      describe 'filtering by single act ID' do
        context 'when act has one gig' do
          before { get :index, params: { act_ids: [ act2.id ] } }

          it { expect(JSON.parse(response.body).length).to eq 1 }
          it { expect(JSON.parse(response.body).first['venue']['name']).to eq honolulu_name }
          it { expect(JSON.parse(response.body).first['acts'].map { |a| a['name'] })
                 .to include act2_name }
        end

        context 'when act has multiple gigs' do
          before { get :index, params: { act_ids: [ act1.id ] } }

          it { expect(JSON.parse(response.body).length).to eq 2 }
          it { expect(JSON.parse(response.body).map { |gig| gig['venue']['name'] })
                 .to contain_exactly tokyo_name, fiji_name }
          it 'includes the filtered act in all returned gigs' do
            JSON.parse(response.body).each do |gig|
              expect(gig['acts'].map { |a| a['name'] }).to include act1_name
            end
          end
          it 'returns all acts for each gig, not just the filtered act' do
            fiji_gig = JSON.parse(response.body).find { |gig| gig['venue']['name'] == fiji_name }
            expect(fiji_gig['acts'].map { |a| a['name'] }).to contain_exactly act1_name, act3_name
          end
        end
      end

      describe 'filtering by multiple act IDs as array' do
        before { get :index, params: { act_ids: [ act1.id, act2.id ] } }

        it { expect(JSON.parse(response.body).length).to eq 3 }
        it { expect(JSON.parse(response.body).map { |gig| gig['venue']['name'] })
               .to contain_exactly tokyo_name, honolulu_name, fiji_name }
        it 'returns gigs that have at least one of the specified acts' do
          response_acts = JSON.parse(response.body).flat_map { |gig| gig['acts'].map { |a| a['name'] } }
          expect(response_acts).to include act1_name, act2_name
        end
        it 'returns all acts for each gig, including non-filtered acts' do
          fiji_gig = JSON.parse(response.body).find { |gig| gig['venue']['name'] == fiji_name }
          expect(fiji_gig['acts'].map { |a| a['name'] }).to contain_exactly act1_name, act3_name
        end
      end

      describe 'filtering by multiple act IDs as comma-separated string' do
        before { get :index, params: { act_ids: "#{act2.id},#{act3.id}" } }

        it { expect(JSON.parse(response.body).length).to eq 2 }
        it { expect(JSON.parse(response.body).map { |gig| gig['venue']['name'] })
               .to contain_exactly honolulu_name, fiji_name }
        it 'returns gigs that have at least one of the specified acts' do
          response_acts = JSON.parse(response.body).flat_map { |gig| gig['acts'].map { |a| a['name'] } }
          expect(response_acts).to include act2_name, act3_name
        end
      end

      describe 'filtering by non-existent act ID' do
        before { get :index, params: { act_ids: [ 99999 ] } }

        it { expect(JSON.parse(response.body).length).to eq 0 }
      end

      describe 'filtering by mix of valid and invalid act IDs' do
        before { get :index, params: { act_ids: [ act1.id, 99999 ] } }

        it { expect(JSON.parse(response.body).length).to eq 2 }
        it { expect(JSON.parse(response.body).map { |gig| gig['venue']['name'] })
               .to match_array [ tokyo_name, fiji_name ] }
      end

      describe 'combining act_ids with bounds parameters' do
        context 'when both filters match some gigs' do
          before do
            get :index, params: {
              act_ids: [ act1.id ],
              north: 36.0,
              south: 35.0,
              east: 140.0,
              west: 139.0
            }
          end

          it { expect(JSON.parse(response.body).length).to eq 1 }
          it { expect(JSON.parse(response.body).first['venue']['name']).to eq tokyo_name }
        end

        context 'when bounds exclude all gigs with specified acts' do
          before do
            get :index, params: {
              act_ids: [ act2.id ],
              north: 36.0,
              south: 35.0,
              east: 140.0,
              west: 139.0
            }
          end

          it { expect(JSON.parse(response.body).length).to eq 0 }
        end
      end

      describe 'without act_ids parameter' do
        before { get :index }

        it 'returns all gigs regardless of acts' do
          expect(JSON.parse(response.body).length).to eq 3
        end
      end
    end
  end
end
