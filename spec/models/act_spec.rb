require 'rails_helper'

RSpec.describe Act, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should have_and_belong_to_many(:gigs) }
  end

  describe 'attributes' do
    it 'defaults images to an empty hash' do
      expect(Act.new.images).to eq({})
    end
  end

  describe '#primary_image_url' do
    let(:act) { create(:act, images: { 'large' => 'https://example.com/large.jpg', 'medium' => 'https://example.com/medium.jpg' }) }

    it 'returns the URL for large size' do
      expect(act.primary_image_url('large')).to eq('https://example.com/large.jpg')
    end

    it 'returns the URL for medium size' do
      expect(act.primary_image_url('medium')).to eq('https://example.com/medium.jpg')
    end

    it 'returns the first available image if the specified size is not available' do
      expect(act.primary_image_url('small')).to eq('https://example.com/large.jpg')
    end

    describe 'returning nil if no images are available' do
      let(:act) { create(:act, images: {}) }
      it { expect(act.primary_image_url).to eq Act::IMAGE_PLACEHOLDER }
    end
  end

  describe '.performing_between' do
    let(:venue) { create :venue }
    let(:act1_name) { Faker::Movies::BackToTheFuture.character }
    let(:act2_name) { Faker::Movies::Ghostbusters.character }
    let(:act3_name) { Faker::Games::SuperSmashBros.fighter }
    let(:act1) { create :act, name: act1_name }
    let(:act2) { create :act, name: act2_name }
    let(:act3) { create :act, name: act3_name }

    let!(:gig1) { create :gig, start_time: Date.today.noon,
                               end_time: Date.today.noon + 2.hours,
                               venue: venue,
                               acts: [ act1 ] }
    let!(:gig2) { create :gig, start_time: 1.week.from_now.noon,
                               end_time: 1.week.from_now.noon + 2.hours,
                               venue: venue,
                               acts: [ act2 ] }
    let!(:gig3) { create :gig, start_time: 2.weeks.from_now.noon,
                               end_time: 2.weeks.from_now.noon + 2.hours,
                               venue: venue,
                               acts: [ act1, act3 ] }

    let(:end_date) { Date.today }
    let(:acts) { Act.performing_between(Date.today, end_date) }

    describe 'returning acts performing on the exact date' do
      it 'returns acts performing on the exact date' do
        expect(acts).to include(act1)
      end
    end

    describe 'excluding acts not performing on the exact date' do
      let(:end_date) { Date.today }
      it { expect(acts).not_to include(act2) }
      it { expect(acts).not_to include(act3) }
    end

    describe 'including act1 when performing within a date range' do
      let(:end_date) { 1.week.from_now }
      it { expect(acts).to include(act1) }
    end

    describe 'including act2 when performing within a date range' do
      let(:end_date) { 1.week.from_now }
      it { expect(acts).to include(act2) }
    end

    describe 'excluding act3 when not performing within a date range' do
      let(:end_date) { 1.week.from_now }
      it { expect(acts).not_to include(act3) }
    end

    describe 'including act1 when date range covers all gigs' do
      let(:end_date) { 3.weeks.from_now }
      it { expect(acts).to include(act1) }
    end

    describe 'including act2 when date range covers all gigs' do
      let(:end_date) { 3.weeks.from_now }
      it { expect(acts).to include(act2) }
    end

    describe 'including act3 when date range covers all gigs' do
      let(:end_date) { 3.weeks.from_now }
      it { expect(acts).to include(act3) }
    end

    describe 'not returning duplicate acts even if they perform multiple times in the range' do
      let(:end_date) { 3.weeks.from_now }
      it { expect(acts.where(name: act1_name).count).to eq(1) }
    end
  end
end
