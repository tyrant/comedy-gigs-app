require 'rails_helper'

RSpec.describe CountryBounds do
  describe '.misplaced?' do
    it 'doubts coordinates well outside the venue’s country' do
      expect(described_class.misplaced?(48.00641, 0.19035, 'BE')).to be true # Malmedy, as Ticketmaster had it: Le Mans
      expect(described_class.misplaced?(55.9495, 3.1879, 'GB')).to be true   # Edinburgh, east for west: the North Sea
      expect(described_class.misplaced?(36.1434, -86.8046, 'CA')).to be true  # Calgary's Laugh Shop, in Nashville
    end

    it 'accepts coordinates in the country, its islands and its territories' do
      expect(described_class.misplaced?(50.4330, 6.0290, 'BE')).to be false  # Malmedy
      expect(described_class.misplaced?(55.9495, -3.1879, 'GB')).to be false # Edinburgh
      expect(described_class.misplaced?(49.1868, -2.1078, 'GB')).to be false # St Helier, Jersey
      expect(described_class.misplaced?(18.4655, -66.1057, 'US')).to be false # San Juan, Puerto Rico
      expect(described_class.misplaced?(-36.8485, 174.7633, 'nz')).to be false
    end

    it 'doubts the placeholders, with or without a country' do
      expect(described_class.misplaced?(0.0, 0.0, 'CA')).to be true
      expect(described_class.misplaced?('0', '0', nil)).to be true
      expect(described_class.misplaced?(1.0, 1.0, 'SE')).to be true
    end

    it 'takes other coordinates on trust when the country isn’t known' do
      expect(described_class.misplaced?(48.00641, 0.19035, nil)).to be false
      expect(described_class.misplaced?(48.00641, 0.19035, 'ZZ')).to be false
    end

    it 'has nothing to doubt without coordinates' do
      expect(described_class.misplaced?(nil, nil, 'BE')).to be false
    end
  end

  describe '.build' do
    def country(name, code, state, *outlines)
      { 'properties' => { 'ADMIN' => name, 'ISO_A2_EH' => code, 'SOVEREIGNT' => state },
        'geometry' => { 'type' => 'MultiPolygon', 'coordinates' => outlines.map { |outline| [ outline ] } } }
    end

    # Outlines are [ longitude, latitude ] rings, as GeoJSON has them
    let(:features) do
      [
        country('Mainland', 'ML', 'Mainland', [ [ 0, 0 ], [ 4, 0 ], [ 4, 4 ], [ 0, 0 ] ], [ [ 4.5, 1 ], [ 6, 1 ], [ 6, 2 ], [ 4.5, 1 ] ], [ [ 20, 20 ], [ 21, 20 ], [ 21, 21 ], [ 20, 20 ] ]),
        country('Its Island', 'IS', 'Mainland', [ [ 10, 10 ], [ 11, 10 ], [ 11, 11 ], [ 10, 10 ] ]),
        country('Disputed', '-99', 'Disputed', [ [ 30, 30 ], [ 31, 30 ], [ 31, 31 ], [ 30, 30 ] ])
      ]
    end

    subject(:bounds) { described_class.build(features) }

    it 'pads each landmass, joining those whose boxes overlap, and includes the state’s territories' do
      expect(bounds['ML']).to eq [ [ -0.5, -0.5, 4.5, 6.5 ], [ 9.5, 9.5, 11.5, 11.5 ], [ 19.5, 19.5, 21.5, 21.5 ] ]
      expect(bounds['IS']).to eq bounds['ML']
    end

    it 'leaves out territories without a country code' do
      expect(bounds.keys).to eq %w[IS ML]
    end
  end
end
