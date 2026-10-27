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
    let!(:venue1) { create :venue, latitude: 40.7128, longitude: -74.0060 } # NYC
    let!(:venue2) { create :venue, latitude: 34.0522, longitude: -118.2437 } # LA
    let!(:venue3) { create :venue, latitude: 51.5074, longitude: -0.1278 } # London

    let!(:act1) { create :act, name: 'Comedian One' }
    let!(:act2) { create :act, name: 'Comedian Two' }
    let!(:act3) { create :act, name: 'Comedian Three' }

    let!(:gig1) { create :gig, start_time: 1.week.from_now,
                               end_time: 1.week.from_now + 2.hours,
                               venue: venue1,
                               acts: [ act1, act2 ] }
    let!(:gig2) { create :gig, start_time: 2.weeks.from_now,
                               end_time: 2.weeks.from_now + 2.hours,
                               venue: venue2,
                               acts: [ act2, act3 ] }
    let!(:gig3) { create :gig, start_time: 3.weeks.from_now,
                               end_time: 3.weeks.from_now + 2.hours,
                               venue: venue3,
                               acts: [ act1 ] }
    let!(:past_gig) { create :gig, start_time: 1.week.ago,
                                   end_time: 1.week.ago + 2.hours,
                                   venue: venue1,
                                   acts: [ act1 ] }

    describe '.between' do
      let(:start_date) { 0.5.weeks.from_now.beginning_of_day }
      let(:end_date) { 2.5.weeks.from_now.end_of_day }
      let(:gigs_in_range) { Gig.between start_date, end_date }

      it { expect(gigs_in_range).to include gig1, gig2 }
      it { expect(gigs_in_range).not_to include gig3, past_gig }
    end

    describe '.by_status' do
      let!(:cancelled_gig) { create :gig, status: 'cancelled',
                                          start_time: 1.day.from_now,
                                          end_time: 1.day.from_now + 2.hours,
                                          venue: venue1 }
      let(:cancelled_gigs) { Gig.by_status 'cancelled' }

      it { expect(cancelled_gigs).to include cancelled_gig }
      it { expect(cancelled_gigs).not_to include gig1, gig2, gig3 }
    end

    describe '.featuring_act' do
      let(:gigs_with_act1) { Gig.featuring_act act1.id }

      it { expect(gigs_with_act1).to include gig1, gig3, past_gig }
      it { expect(gigs_with_act1).not_to include gig2 }
    end

    describe '.featuring_acts' do
      context 'with blank act_ids' do
        it { expect(Gig.featuring_acts(nil)).to eq(Gig.all) }
        it { expect(Gig.featuring_acts([])).to eq(Gig.all) }
      end

      context 'with valid act_ids' do
        let(:gigs_with_multiple_acts) { Gig.featuring_acts([ act1.id, act3.id ]) }
        let(:gigs_with_act2) { Gig.featuring_acts([ act2.id ]) }

        it { expect(gigs_with_multiple_acts).to include gig1, gig2, gig3, past_gig }
        it { expect(gigs_with_act2).to include gig1, gig2 }
        it { expect(gigs_with_act2).not_to include gig3, past_gig }
      end
    end

    describe '.starting_after' do
      context 'with blank start_date' do
        it { expect(Gig.starting_after(nil)).to eq Gig.all }
        it { expect(Gig.starting_after('')).to eq Gig.all }
      end

      context 'with valid start_date' do
        let(:start_date) { 1.5.weeks.from_now.to_date.to_s }
        let(:gigs_after) { Gig.starting_after(start_date) }

        it { expect(gigs_after).to include gig2, gig3 }
        it { expect(gigs_after).not_to include gig1, past_gig }
      end

      context 'with invalid start_date' do
        it { expect(Gig.starting_after('invalid-date')).to eq Gig.all }
      end
    end

    describe '.starting_before' do
      context 'with blank end_date' do
        it { expect(Gig.starting_before(nil)).to eq Gig.all }
        it { expect(Gig.starting_before('')).to eq Gig.all }
      end

      context 'with valid end_date' do
        let(:end_date) { 1.5.weeks.from_now.to_date.to_s }
        let(:gigs_before) { Gig.starting_before(end_date) }

        it { expect(gigs_before).to include gig1, past_gig }
        it { expect(gigs_before).not_to include gig2, gig3 }
      end

      context 'with invalid end_date' do
        it { expect(Gig.starting_before('invalid-date')).to eq Gig.all }
      end
    end
  end

  # Test class methods
  describe 'class methods' do
    let!(:venue1) { create :venue, latitude: 40.7128, longitude: -74.0060 } # NYC
    let!(:venue2) { create :venue, latitude: 34.0522, longitude: -118.2437 } # LA
    let!(:venue3) { create :venue, latitude: 51.5074, longitude: -0.1278 } # London

    let!(:act1) { create :act, name: 'Comedian One' }
    let!(:act2) { create :act, name: 'Comedian Two' }

    let!(:gig1) { create :gig, venue: venue1,
                               start_time: 1.day.from_now,
                               end_time: 1.day.from_now + 2.hours,
                               acts: [ act1 ] }
    let!(:gig2) { create :gig, venue: venue2,
                               start_time: 2.days.from_now,
                               end_time: 2.days.from_now + 2.hours,
                               acts: [ act2 ] }
    let!(:gig3) { create :gig, venue: venue3,
                               start_time: 3.days.from_now,
                               end_time: 3.days.from_now + 2.hours,
                               acts: [ act1, act2 ] }

    describe '.filtered_for_api' do
      context 'with no parameters' do
        it { expect(Gig.filtered_for_api({})).to include gig1, gig2, gig3 }
      end

      context 'with a cancelled gig' do
        let!(:cancelled_gig) { create :gig, status: 'cancelled', venue: venue1 }

        it { expect(Gig.filtered_for_api({})).not_to include cancelled_gig }
      end

      context 'with act_ids parameter' do
        context 'with multiple act_ids' do
          let(:result) { Gig.filtered_for_api(act_ids: "#{act1.id},#{act2.id}") }

          it { expect(result).to include gig1, gig2, gig3 }
        end

        context 'with single act_id' do
          let(:result) { Gig.filtered_for_api(act_ids: act1.id.to_s) }

          it { expect(result).to include gig1, gig3 }
          it { expect(result).not_to include gig2 }
        end

        context 'with junk in the list' do
          let(:result) { Gig.filtered_for_api(act_ids: "#{act1.id},abc,") }

          it { expect(result).to contain_exactly gig1, gig3 }
        end

        it 'lists each gig once when several of its acts match' do
          expect(Gig.filtered_for_api(act_ids: "#{act1.id},#{act2.id}").where(id: gig3).count).to eq 1
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

        it { expect(result).to include gig2 }
        it { expect(result).not_to include gig1, gig3 }
      end

      context 'with combined parameters' do
        let(:params) do
          {
            act_ids: act1.id.to_s,
            start_date: 0.5.days.from_now.to_date.to_s,
            end_date: 1.5.days.from_now.to_date.to_s
          }
        end

        it { expect(Gig.filtered_for_api(params)).to contain_exactly gig1 }
      end
    end
  end

  # Test private class methods
  describe 'private class methods' do
    describe '.parse_date' do
      context 'with valid date string' do
        let(:date_string) { '2024-12-25' }
        let(:result) { Gig.send(:parse_date, date_string) }

        it { expect(result).to eq Date.parse(date_string) }
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
