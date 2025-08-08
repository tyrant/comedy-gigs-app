require 'rails_helper'

RSpec.describe Gig, type: :model do
  describe 'associations' do
    it { should belong_to(:venue) }
    it { should have_and_belong_to_many(:acts) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:start_time) }
    it { should validate_inclusion_of(:status).in_array(%w[scheduled cancelled postponed sold_out]) }

    describe 'end_time_after_start_time validation' do
      let(:gig) { build(:gig, start_time: 1.hour.from_now, end_time: 30.minutes.from_now) }

      it 'is invalid when end_time is before start_time' do
        expect(gig).to be_invalid
        expect(gig.errors[:end_time]).to include('must be after start time')
      end

      it 'is valid when end_time is after start_time' do
        gig.end_time = 2.hours.from_now
        expect(gig).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:venue1) { create(:venue, latitude: 40.7128, longitude: -74.0060) } # NYC
    let!(:venue2) { create(:venue, latitude: 34.0522, longitude: -118.2437) } # LA
    let!(:venue3) { create(:venue, latitude: 51.5074, longitude: -0.1278) } # London

    let!(:act1) { create(:act, name: 'Comedian One') }
    let!(:act2) { create(:act, name: 'Comedian Two') }
    let!(:act3) { create(:act, name: 'Comedian Three') }

    let!(:gig1) { create(:gig, venue: venue1, start_time: 1.day.from_now, end_time: 1.day.from_now + 2.hours, acts: [ act1, act2 ]) }
    let!(:gig2) { create(:gig, venue: venue2, start_time: 2.days.from_now, end_time: 2.days.from_now + 2.hours, acts: [ act2, act3 ]) }
    let!(:gig3) { create(:gig, venue: venue3, start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours, acts: [ act1 ]) }
    let!(:past_gig) { create(:gig, venue: venue1, start_time: 1.day.ago, end_time: 1.day.ago + 2.hours, acts: [ act1 ]) }

    describe '.upcoming' do
      let(:upcoming_gigs) { Gig.upcoming }

      it { expect(upcoming_gigs).to include(gig1, gig2, gig3) }
      it { expect(upcoming_gigs).not_to include(past_gig) }
      it { expect(upcoming_gigs.first).to eq(gig1) }
      it { expect(upcoming_gigs.last).to eq(gig3) }
    end

    describe '.past' do
      let(:past_gigs) { Gig.past }

      it { expect(past_gigs).to include(past_gig) }
      it { expect(past_gigs).not_to include(gig1, gig2, gig3) }

      describe 'ordering' do
        let!(:past_gig2) { create(:gig, venue: venue1, start_time: 2.days.ago, end_time: 2.days.ago + 2.hours, acts: [ act1 ]) }

        it { expect(past_gigs.first).to eq(past_gig) }
        it { expect(past_gigs.last).to eq(past_gig2) }
      end
    end

    describe '.between' do
      let(:start_date) { 1.day.from_now.beginning_of_day }
      let(:end_date) { 2.days.from_now.end_of_day }
      let(:gigs_in_range) { Gig.between(start_date, end_date) }

      it { expect(gigs_in_range).to include(gig1, gig2) }
      it { expect(gigs_in_range).not_to include(gig3, past_gig) }
    end

    describe '.by_status' do
      let!(:cancelled_gig) { create(:gig, status: 'cancelled', venue: venue1, start_time: 1.day.from_now, end_time: 1.day.from_now + 2.hours) }
      let(:cancelled_gigs) { Gig.by_status('cancelled') }

      it { expect(cancelled_gigs).to include(cancelled_gig) }
      it { expect(cancelled_gigs).not_to include(gig1, gig2, gig3) }
    end

    describe '.featuring_act' do
      let(:gigs_with_act1) { Gig.featuring_act(act1.id) }

      it { expect(gigs_with_act1).to include(gig1, gig3, past_gig) }
      it { expect(gigs_with_act1).not_to include(gig2) }
    end

    describe '.within_bounds' do
      # Bounds that include NYC and LA but not London
      let(:sw) { [ 30.0, -125.0 ] }
      let(:ne) { [ 45.0, -70.0 ] }
      let(:bounds) { [ sw, ne ] }
      let(:gigs_in_bounds) { Gig.within_bounds(bounds) }

      it { expect(gigs_in_bounds).to include(gig1, gig2, past_gig) }
      it { expect(gigs_in_bounds).not_to include(gig3) }
    end

    describe '.featuring_acts' do
      context 'with blank act_ids' do
        it { expect(Gig.featuring_acts(nil)).to eq(Gig.all) }
        it { expect(Gig.featuring_acts([])).to eq(Gig.all) }
      end

      context 'with valid act_ids' do
        let(:gigs_with_multiple_acts) { Gig.featuring_acts([ act1.id, act3.id ]) }
        let(:gigs_with_act2) { Gig.featuring_acts([ act2.id ]) }

        it { expect(gigs_with_multiple_acts).to include(gig1, gig2, gig3, past_gig) }
        it { expect(gigs_with_act2).to include(gig1, gig2) }
        it { expect(gigs_with_act2).not_to include(gig3, past_gig) }
      end
    end

    describe '.starting_after' do
      context 'with blank start_date' do
        it { expect(Gig.starting_after(nil)).to eq(Gig.all) }
        it { expect(Gig.starting_after('')).to eq(Gig.all) }
      end

      context 'with valid start_date' do
        let(:start_date) { 1.5.days.from_now.to_date.to_s }
        let(:gigs_after) { Gig.starting_after(start_date) }

        it { expect(gigs_after).to include(gig1, gig2, gig3) }
        it { expect(gigs_after).not_to include(past_gig) }
      end

      context 'with invalid start_date' do
        it { expect(Gig.starting_after('invalid-date')).to eq(Gig.all) }
      end
    end

    describe '.starting_before' do
      context 'with blank end_date' do
        it { expect(Gig.starting_before(nil)).to eq(Gig.all) }
        it { expect(Gig.starting_before('')).to eq(Gig.all) }
      end

      context 'with valid end_date' do
        let(:end_date) { 1.day.from_now.to_date.to_s }
        let(:gigs_before) { Gig.starting_before(end_date) }

        # gig1 starts at 1.day.from_now, which should be included (same day, before end of day)
        # past_gig starts 1.day.ago, which is definitely before the end_date
        # gig2 starts at 2.days.from_now, gig3 starts at 3.days.from_now - both after end_date
        it { expect(gigs_before).to include(gig1, past_gig) }
        it { expect(gigs_before).not_to include(gig2, gig3) }
      end

      context 'with invalid end_date' do
        it { expect(Gig.starting_before('invalid-date')).to eq(Gig.all) }
      end
    end
  end

  # Test class methods
  describe 'class methods' do
    let!(:venue1) { create(:venue, latitude: 40.7128, longitude: -74.0060) } # NYC
    let!(:venue2) { create(:venue, latitude: 34.0522, longitude: -118.2437) } # LA
    let!(:venue3) { create(:venue, latitude: 51.5074, longitude: -0.1278) } # London

    let!(:act1) { create(:act, name: 'Comedian One') }
    let!(:act2) { create(:act, name: 'Comedian Two') }

    let!(:gig1) { create(:gig, venue: venue1, start_time: 1.day.from_now, end_time: 1.day.from_now + 2.hours, acts: [ act1 ]) }
    let!(:gig2) { create(:gig, venue: venue2, start_time: 2.days.from_now, end_time: 2.days.from_now + 2.hours, acts: [ act2 ]) }
    let!(:gig3) { create(:gig, venue: venue3, start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours, acts: [ act1, act2 ]) }

    describe '.filtered_for_api' do
      context 'with no parameters' do
        let(:result) { Gig.filtered_for_api({}) }

        it { expect(result.to_a).to include(gig1, gig2, gig3) }
        it { expect(result.includes_values).to include(:venue, :acts) }
      end

      context 'with bounds parameters' do
        let(:params) do
          {
            north: 45.0,
            south: 30.0,
            east: -70.0,
            west: -125.0
          }
        end
        let(:result) { Gig.filtered_for_api(params) }

        it { expect(result.to_a).to include(gig1, gig2) }
        it { expect(result.to_a).not_to include(gig3) }
      end

      context 'with incomplete bounds parameters' do
        let(:params) { { north: 45.0, south: 30.0 } }
        let(:result) { Gig.filtered_for_api(params) }

        it { expect(result.to_a).to include(gig1, gig2, gig3) }
      end

      context 'with act_ids parameter' do
        context 'with multiple act_ids' do
          let(:params) { { act_ids: "#{act1.id},#{act2.id}" } }
          let(:result) { Gig.filtered_for_api(params) }

          it { expect(result.to_a).to include(gig1, gig2, gig3) }
        end

        context 'with single act_id' do
          let(:params) { { act_ids: act1.id.to_s } }
          let(:result) { Gig.filtered_for_api(params) }

          it { expect(result.to_a).to include(gig1, gig3) }
          it { expect(result.to_a).not_to include(gig2) }
        end
      end

      context 'with date parameters' do
        let(:params) do
          {
            start_date: 2.days.from_now.to_date.to_s,
            end_date: 2.days.from_now.to_date.to_s
          }
        end
        let(:result) { Gig.filtered_for_api(params) }

        # Only gig2 starts exactly on 2.days.from_now date, so it should be included
        # gig1 starts at 1.day.from_now, which is before the start_date
        # gig3 starts at 3.days.from_now, which is after the end_date
        it { expect(result.to_a).to include(gig2) }
        it { expect(result.to_a).not_to include(gig1, gig3) }
      end

      context 'with combined parameters' do
        let(:params) do
          {
            north: 45.0,
            south: 30.0,
            east: -70.0,
            west: -125.0,
            act_ids: act1.id.to_s,
            start_date: 0.5.days.from_now.to_date.to_s,
            end_date: 1.5.days.from_now.to_date.to_s
          }
        end
        let(:result) { Gig.filtered_for_api(params) }

        it { expect(result.to_a).to include(gig1) }
        it { expect(result.to_a).not_to include(gig2, gig3) }
      end

      describe 'ordering' do
        let(:result) { Gig.filtered_for_api({}) }

        it { expect(result.order_values.first.to_sql).to include('"gigs"."id"') }
      end
    end

    describe '.serialize_for_api' do
      context 'with gigs data' do
        let(:gigs) { [ gig1, gig2 ] }
        let(:result) { Gig.serialize_for_api(gigs) }
        let(:gig_json) { result.first }
        let(:venue_json) { gig_json['venue'] }
        let(:acts_json) { gig_json['acts'] }

        it { expect(result).to be_an(Array) }
        it { expect(result.length).to eq(2) }
        it { expect(gig_json).to have_key('name') }
        it { expect(gig_json).to have_key('venue') }
        it { expect(gig_json).to have_key('acts') }
        it { expect(venue_json).to have_key('latitude') }
        it { expect(venue_json).to have_key('longitude') }
        it { expect(venue_json).to have_key('primary_image_url') }
        it { expect(acts_json).to be_an(Array) }
        it { expect(acts_json.first).to have_key('primary_image_url') }
      end

      context 'with empty gigs array' do
        let(:result) { Gig.serialize_for_api([]) }

        it { expect(result).to eq([]) }
      end
    end
  end

  # Test private class methods
  describe 'private class methods' do
    describe '.bounds_params_present?' do
      context 'with complete bounds parameters' do
        let(:params) { { north: 45.0, south: 30.0, east: -70.0, west: -125.0 } }

        it { expect(Gig.send(:bounds_params_present?, params)).to be true }
      end

      context 'with missing bounds parameters' do
        let(:params) { { north: 45.0, south: 30.0, east: -70.0 } }

        it { expect(Gig.send(:bounds_params_present?, params)).to be false }
      end

      context 'with blank bounds parameters' do
        let(:params) { { north: '', south: 30.0, east: -70.0, west: -125.0 } }

        it { expect(Gig.send(:bounds_params_present?, params)).to be false }
      end
    end

    describe '.parse_date' do
      context 'with valid date string' do
        let(:date_string) { '2024-12-25' }
        let(:result) { Gig.send(:parse_date, date_string) }

        it { expect(result).to eq(Date.parse(date_string)) }
      end

      context 'with invalid date string' do
        let(:result) { Gig.send(:parse_date, 'invalid-date') }

        it { expect(result).to be_nil }
      end

      context 'with nil input' do
        let(:result) { Gig.send(:parse_date, nil) }

        it { expect(result).to be_nil }
      end
    end
  end
end
