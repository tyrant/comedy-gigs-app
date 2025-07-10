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
      venue = Venue.new
      expect(venue.images).to eq({})
    end
  end

  describe '#primary_image_url' do
    let(:venue) { create(:venue, images: { 'large' => 'https://example.com/large.jpg', 'medium' => 'https://example.com/medium.jpg' }) }

    it 'returns the URL for the specified size' do
      expect(venue.primary_image_url('large')).to eq('https://example.com/large.jpg')
      expect(venue.primary_image_url('medium')).to eq('https://example.com/medium.jpg')
    end

    it 'returns the first available image if the specified size is not available' do
      expect(venue.primary_image_url('small')).to eq('https://example.com/large.jpg')
    end

    it 'returns nil if no images are available' do
      venue.update(images: {})
      expect(venue.primary_image_url).to be_nil
    end
  end

  describe 'geocoding' do
    let(:venue) { build(:venue, address: '123 Main St', city: 'New York', country: 'USA') }

    it 'sets latitude and longitude when address is updated' do
      # This test assumes geocoding is working in test environment
      # You might want to stub the geocoding service in a real test
      venue.save
      expect(venue.latitude).not_to be_nil
      expect(venue.longitude).not_to be_nil
    end
  end
end
