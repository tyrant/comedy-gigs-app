require 'rails_helper'

RSpec.describe Api::TicketmasterTransformer do
  describe '.extract_images' do
    context 'with valid image data' do
      let(:images_data) do
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

      it 'extracts images and categorizes them by size' do
        result = described_class.extract_images(images_data)
        
        expect(result).to be_a(Hash)
        expect(result.keys).to include('large', 'medium', 'square', 'standard')
        expect(result['large']).to eq('https://example.com/image1.jpg')
        expect(result['medium']).to eq('https://example.com/image2.jpg')
        expect(result['square']).to eq('https://example.com/image3.jpg')
        expect(result['standard']).to eq('https://example.com/image4.jpg')
      end
      
      it 'ignores fallback images' do
        fallback_image = {
          'url' => 'https://example.com/fallback.jpg',
          'ratio' => '16_9',
          'width' => 1024,
          'height' => 576,
          'fallback' => true
        }
        
        images_with_fallback = images_data + [fallback_image]
        result = described_class.extract_images(images_with_fallback)
        
        expect(result['large']).to eq('https://example.com/image1.jpg')
        expect(result.values).not_to include('https://example.com/fallback.jpg')
      end
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
      
      it 'skips images without URLs' do
        images_data = [
          { 'ratio' => '16_9', 'width' => 1024, 'height' => 576, 'fallback' => false },
          { 'url' => 'https://example.com/valid.jpg', 'ratio' => '3_2', 'fallback' => false }
        ]
        
        result = described_class.extract_images(images_data)
        expect(result.keys).to include('medium')
        expect(result.keys).not_to include('large')
        expect(result['medium']).to eq('https://example.com/valid.jpg')
      end
    end
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

    it 'includes images in the transformed venue data' do
      result = described_class.build_venue(venue_data)
      
      expect(result).to include(:images)
      expect(result[:images]).to be_a(Hash)
      expect(result[:images]['large']).to eq('https://example.com/venue.jpg')
    end
  end

  describe '.build_acts' do
    let(:act_data) do
      [{
        'name' => 'Funny Person',
        'id' => 'a123',
        'description' => 'Very funny comedian',
        'externalLinks' => {
          'twitter' => [{ 'url' => 'https://twitter.com/funnyperson' }]
        },
        'images' => [
          {
            'url' => 'https://example.com/comedian.jpg',
            'ratio' => '1_1',
            'fallback' => false
          }
        ]
      }]
    end

    it 'includes images in the transformed act data' do
      result = described_class.build_acts(act_data)
      
      expect(result.first).to include(:images)
      expect(result.first[:images]).to be_a(Hash)
      expect(result.first[:images]['square']).to eq('https://example.com/comedian.jpg')
    end
  end
end
