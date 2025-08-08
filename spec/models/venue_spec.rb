require 'rails_helper'

RSpec.describe Venue, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should have_many(:gigs) }
  end

  describe 'attributes' do
    it 'defaults images to an empty hash' do
      expect(Venue.new.images).to eq({})
    end
  end

  describe '#primary_image_url' do
    let(:venue) { create(:venue, images: { 'large' => 'https://example.com/large.jpg', 'medium' => 'https://example.com/medium.jpg' }) }

    it 'returns the URL for large size' do
      expect(venue.primary_image_url('large')).to eq('https://example.com/large.jpg')
    end

    it 'returns the URL for medium size' do
      expect(venue.primary_image_url('medium')).to eq('https://example.com/medium.jpg')
    end

    it 'returns the first available image if the specified size is not available' do
      expect(venue.primary_image_url('small')).to eq('https://example.com/large.jpg')
    end

    describe 'returning nil if no images are available' do
      before { venue.update(images: {}) }
      it { expect(venue.primary_image_url).to eq '/images/venue_placeholder.webp' }
    end
  end

  describe 'geocoding' do
    let(:venue) { build(:venue, address: '123 Main St', city: 'New York', country: 'USA') }

    describe 'sets latitude when address is updated' do
      # This test assumes geocoding is working in test environment
      # You might want to stub the geocoding service in a real test
      before { venue.save }
      it { expect(venue.latitude).not_to be_nil }
    end

    describe 'sets longitude when address is updated' do
      # This test assumes geocoding is working in test environment
      # You might want to stub the geocoding service in a real test
      before { venue.save }
      it { expect(venue.longitude).not_to be_nil }
    end
  end
end
