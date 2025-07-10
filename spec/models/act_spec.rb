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
      act = Act.new
      expect(act.images).to eq({})
    end
  end

  describe '#primary_image_url' do
    let(:act) { create(:act, images: { 'large' => 'https://example.com/large.jpg', 'medium' => 'https://example.com/medium.jpg' }) }

    it 'returns the URL for the specified size' do
      expect(act.primary_image_url('large')).to eq('https://example.com/large.jpg')
      expect(act.primary_image_url('medium')).to eq('https://example.com/medium.jpg')
    end

    it 'returns the first available image if the specified size is not available' do
      expect(act.primary_image_url('small')).to eq('https://example.com/large.jpg')
    end

    it 'returns nil if no images are available' do
      act.update(images: {})
      expect(act.primary_image_url).to be_nil
    end
  end

  describe '.performing_between' do
    let(:venue) { create(:venue) }
    let(:act1) { create(:act, name: 'Act 1') }
    let(:act2) { create(:act, name: 'Act 2') }
    let(:act3) { create(:act, name: 'Act 3') }

    before do
      # Create gigs with different dates
      gig1 = create(:gig, venue: venue, start_time: Date.today.noon)
      gig2 = create(:gig, venue: venue, start_time: 1.week.from_now.noon)
      gig3 = create(:gig, venue: venue, start_time: 2.weeks.from_now.noon)
      
      # Associate acts with gigs
      gig1.acts << act1
      gig2.acts << act2
      gig3.acts << act3
      # Act1 also performs in a future gig
      gig3.acts << act1
    end

    it 'returns acts performing on the exact date' do
      acts = Act.performing_between(Date.today, Date.today)
      expect(acts).to include(act1)
      expect(acts).not_to include(act2, act3)
    end

    it 'returns acts performing within a date range' do
      acts = Act.performing_between(Date.today, 1.week.from_now)
      expect(acts).to include(act1, act2)
      expect(acts).not_to include(act3)
    end

    it 'returns all acts when the date range covers all gigs' do
      acts = Act.performing_between(Date.today, 3.weeks.from_now)
      expect(acts).to include(act1, act2, act3)
    end

    it 'does not return duplicate acts even if they perform multiple times in the range' do
      acts = Act.performing_between(Date.today, 3.weeks.from_now)
      expect(acts.where(name: 'Act 1').count).to eq(1)
    end
  end
end
