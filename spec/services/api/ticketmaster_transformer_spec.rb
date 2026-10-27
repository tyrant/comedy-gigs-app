require 'rails_helper'

RSpec.describe Api::TicketmasterTransformer do
  describe '.extract_images' do
    context 'with valid image data' do
      let(:images) do
        [
          {
            'url' => 'https://example.com/image1.jpg',
            'ratio' => '16_9',
            'width' => 1024,
            'height' => 576,
            'fallback' => false
          },
          {
            'url' => 'https://example.com/image2.jpg',
            'ratio' => '3_2',
            'width' => 600,
            'height' => 400,
            'fallback' => false
          },
          {
            'url' => 'https://example.com/image3.jpg',
            'ratio' => '1_1',
            'width' => 300,
            'height' => 300,
            'fallback' => false
          },
          {
            'url' => 'https://example.com/image4.jpg',
            'ratio' => 'custom',
            'width' => 800,
            'height' => 600,
            'fallback' => false
          }
        ]
      end

      let(:images_data) { images }
      let(:result) { described_class.extract_images(images_data) }

      it { expect(result).to be_a(Hash) }
      it { expect(result.keys).to include('large', 'medium', 'square', 'standard') }
      it { expect(result['large']).to eq('https://example.com/image1.jpg') }
      it { expect(result['medium']).to eq('https://example.com/image2.jpg') }
      it { expect(result['square']).to eq('https://example.com/image3.jpg') }
      it { expect(result['standard']).to eq('https://example.com/image4.jpg') }

      let(:fallback_image) { { 'url' => 'https://example.com/fallback.jpg',
                               'ratio' => '16_9',
                               'width' => 1024,
                               'height' => 576,
                               'fallback' => true } }

      describe 'preferring non-fallback images for large size' do
        let(:images_data) { images + [ fallback_image ] }
        it { expect(result['large']).to eq('https://example.com/image1.jpg') }
      end

      describe 'excluding fallback images from results' do
        let(:images_data) { images + [ fallback_image ] }
        it { expect(result.values).not_to include('https://example.com/fallback.jpg') }
      end
    end

    context 'with the full range of sizes Ticketmaster offers' do
      let(:images_data) do
        [
          [ '16_9', 100, 56 ], [ '16_9', 205, 115 ], [ '16_9', 640, 360 ], [ '16_9', 2426, 1365 ],
          [ '3_2', 305, 203 ], [ '3_2', 640, 427 ], [ '3_2', 1024, 683 ]
        ].map { |ratio, width, height| { 'url' => "https://example.com/#{ratio}_#{width}.jpg", 'ratio' => ratio, 'width' => width, 'height' => height } }
      end
      let(:result) { described_class.extract_images(images_data) }

      it 'picks the narrowest image at least 640px wide for each ratio, not the original' do
        expect(result['large']).to eq 'https://example.com/16_9_640.jpg'
        expect(result['medium']).to eq 'https://example.com/3_2_640.jpg'
      end

      it 'picks the smallest image whose short side covers a retina avatar as the thumbnail' do
        expect(result['thumb']).to eq 'https://example.com/16_9_205.jpg'
      end
    end

    context 'when every image is smaller than the preferred sizes' do
      let(:images_data) { [ { 'url' => 'https://example.com/tiny.jpg', 'ratio' => '16_9', 'width' => 100, 'height' => 56 } ] }
      let(:result) { described_class.extract_images(images_data) }

      it { expect(result['large']).to eq 'https://example.com/tiny.jpg' }
      it { expect(result['thumb']).to eq 'https://example.com/tiny.jpg' }
    end

    context 'with invalid image data' do
      it 'returns an empty hash when images_data is nil' do
        expect(described_class.extract_images(nil)).to eq({})
      end

      it 'returns an empty hash when images_data is empty' do
        expect(described_class.extract_images([])).to eq({})
      end

      it 'returns an empty hash when images_data is not an array' do
        expect(described_class.extract_images('not an array')).to eq({})
      end

      let(:images_data) { [
        { 'ratio' => '16_9', 'width' => 1024, 'height' => 576, 'fallback' => false },
        { 'url' => 'https://example.com/valid.jpg', 'ratio' => '3_2', 'fallback' => false }
      ] }
      let(:result) { described_class.extract_images(images_data) }

      it 'includes medium size from valid image' do
        expect(result.keys).to include('medium')
      end

      it 'creates fallback for large size when URL is missing' do
        expect(result.keys).to include('large')
      end

      it 'creates fallback for standard size when URL is missing' do
        expect(result.keys).to include('standard')
      end

      it 'creates fallback for square size when URL is missing' do
        expect(result.keys).to include('square')
      end

      it 'uses valid URL for medium size' do
        expect(result['medium']).to eq('https://example.com/valid.jpg')
      end
    end
  end

  describe '.build_acts with messy attractions' do
    let(:result) do
      described_class.build_acts([
        { 'id' => 'a1', 'name' => 'Joanne McNally' },
        { 'id' => 'a1', 'name' => 'Joanne McNally' },
        { 'id' => 'a2', 'name' => '' },
        { 'name' => 'No ID One' },
        { 'name' => 'No ID Two' }
      ])
    end

    it 'drops nameless and repeated attractions' do
      expect(result.map { |act| act[:name] }).to eq [ 'Joanne McNally', 'No ID One', 'No ID Two' ]
    end
  end

  describe '.build_venue without a street address' do
    let(:venue) { { 'id' => 'v1', 'name' => 'Cavern Club', 'city' => { 'name' => 'Sao Paulo' } } }

    it { expect(described_class.build_venue(venue)[:address]).to eq 'Sao Paulo' }
    it { expect(described_class.build_venue(venue.except('city'))[:address]).to eq 'Cavern Club' }
  end

  describe '.build_venue without a name' do
    let(:venue) { { 'id' => 'v2', 'address' => { 'line1' => 'Youngs gate 6' }, 'city' => { 'name' => 'Oslo' } } }

    it { expect(described_class.build_venue(venue)[:name]).to eq 'Youngs gate 6' }
  end

  describe '.build_venue' do
    let(:venue_data) do
      {
        'name' => 'Comedy Club',
        'id' => 'v123',
        'address' => { 'line1' => '123 Laugh St' },
        'city' => { 'name' => 'Funnytown' },
        'country' => { 'name' => 'Jokeland' },
        'location' => { 'latitude' => '40.7128', 'longitude' => '-74.0060' },
        'description' => 'A place for comedy',
        'capacity' => '200',
        'images' => [
          {
            'url' => 'https://example.com/venue.jpg',
            'ratio' => '16_9',
            'fallback' => false
          }
        ]
      }
    end

    describe 'including images in the transformed venue data' do
      let(:result) { described_class.build_venue(venue_data) }

      it { expect(result).to include(:images) }
      it { expect(result[:images]).to be_a(Hash) }
      it { expect(result[:images]['large']).to eq('https://example.com/venue.jpg') }
    end
  end

  describe '.build_acts' do
    let(:act_data) do
      [ {
        'name' => 'Funny Person',
        'id' => 'a123',
        'description' => 'Very funny comedian',
        'externalLinks' => {
          'twitter' => [ { 'url' => 'https://twitter.com/funnyperson' } ]
        },
        'images' => [
          {
            'url' => 'https://example.com/comedian.jpg',
            'ratio' => '1_1',
            'fallback' => false
          }
        ]
      } ]
    end

    describe 'including images in the transformed act data' do
      let(:result) { described_class.build_acts(act_data) }

      it { expect(result.first).to include(:images) }
      it { expect(result.first[:images]).to be_a(Hash) }
      it { expect(result.first[:images]['square']).to eq('https://example.com/comedian.jpg') }
    end
  end

  describe '.extract_timezone' do
    context 'with valid timezone in venue data' do
      let(:venue_with_timezone) do
        {
          'name' => 'Test Venue',
          'timezone' => 'America/New_York'
        }
      end

      it 'extracts the timezone from venue data' do
        result = described_class.extract_timezone(venue_with_timezone)
        expect(result).to eq('America/New_York')
      end
    end

    context 'with invalid timezone in venue data' do
      let(:venue_with_invalid_timezone) do
        {
          'name' => 'Test Venue',
          'timezone' => 'Invalid/Timezone'
        }
      end

      it 'returns nil for invalid timezone' do
        result = described_class.extract_timezone(venue_with_invalid_timezone)
        expect(result).to be_nil
      end
    end

    context 'without timezone in venue data' do
      let(:venue_without_timezone) do
        {
          'name' => 'Test Venue',
          'country' => { 'name' => 'United States' },
          'city' => { 'name' => 'New York' }
        }
      end

      it 'infers timezone from location' do
        result = described_class.extract_timezone(venue_without_timezone)
        expect(result).to eq('America/New_York')
      end
    end
  end

  describe '.infer_timezone_from_location' do
    context 'with US locations' do
      it 'returns correct timezone for New York' do
        result = described_class.infer_timezone_from_location('United States', 'New York')
        expect(result).to eq('America/New_York')
      end

      it 'returns correct timezone for Los Angeles' do
        result = described_class.infer_timezone_from_location('United States', 'Los Angeles')
        expect(result).to eq('America/Los_Angeles')
      end

      it 'returns correct timezone for Chicago' do
        result = described_class.infer_timezone_from_location('United States', 'Chicago')
        expect(result).to eq('America/Chicago')
      end

      it 'returns correct timezone for Denver' do
        result = described_class.infer_timezone_from_location('United States', 'Denver')
        expect(result).to eq('America/Denver')
      end

      it 'defaults to Eastern time for unknown US cities' do
        result = described_class.infer_timezone_from_location('United States', 'Unknown City')
        expect(result).to eq('America/New_York')
      end
    end

    context 'with Canadian locations' do
      it 'returns correct timezone for Toronto' do
        result = described_class.infer_timezone_from_location('Canada', 'Toronto')
        expect(result).to eq('America/Toronto')
      end

      it 'returns correct timezone for Vancouver' do
        result = described_class.infer_timezone_from_location('Canada', 'Vancouver')
        expect(result).to eq('America/Vancouver')
      end
    end

    context 'with UK locations' do
      it 'returns London timezone for UK' do
        result = described_class.infer_timezone_from_location('United Kingdom', 'London')
        expect(result).to eq('Europe/London')
      end
    end

    context 'with Australian locations' do
      it 'returns correct timezone for Sydney' do
        result = described_class.infer_timezone_from_location('Australia', 'Sydney')
        expect(result).to eq('Australia/Sydney')
      end

      it 'returns correct timezone for Perth' do
        result = described_class.infer_timezone_from_location('Australia', 'Perth')
        expect(result).to eq('Australia/Perth')
      end
    end

    context 'with unknown countries' do
      it 'returns nil for unknown countries' do
        result = described_class.infer_timezone_from_location('Unknown Country', 'Unknown City')
        expect(result).to be_nil
      end
    end
  end

  describe '.valid_timezone?' do
    it 'returns true for valid IANA timezone' do
      expect(described_class.valid_timezone?('America/New_York')).to be true
    end

    it 'returns false for invalid timezone' do
      expect(described_class.valid_timezone?('Invalid/Timezone')).to be false
    end

    it 'returns false for blank timezone' do
      expect(described_class.valid_timezone?('')).to be false
      expect(described_class.valid_timezone?(nil)).to be false
    end
  end

  describe '.build_venue' do
    context 'with timezone data' do
      let(:venue_data_with_timezone) do
        {
          'name' => 'Madison Square Garden',
          'id' => 'venue123',
          'address' => { 'line1' => '4 Pennsylvania Plaza' },
          'city' => { 'name' => 'New York' },
          'country' => { 'name' => 'United States' },
          'location' => { 'latitude' => '40.7505', 'longitude' => '-73.9934' },
          'timezone' => 'America/New_York',
          'images' => []
        }
      end

      it 'includes timezone in the result' do
        result = described_class.build_venue(venue_data_with_timezone)
        expect(result[:timezone]).to eq('America/New_York')
      end
    end

    context 'without timezone data' do
      let(:venue_data_without_timezone) do
        {
          'name' => 'Test Venue',
          'id' => 'venue456',
          'address' => { 'line1' => '123 Test St' },
          'city' => { 'name' => 'Los Angeles' },
          'country' => { 'name' => 'United States' },
          'location' => { 'latitude' => '34.0522', 'longitude' => '-118.2437' },
          'images' => []
        }
      end

      it 'infers timezone from location' do
        result = described_class.build_venue(venue_data_without_timezone)
        expect(result[:timezone]).to eq('America/Los_Angeles')
      end
    end
  end
end
