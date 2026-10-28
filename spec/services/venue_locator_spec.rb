require 'rails_helper'

RSpec.describe VenueLocator do
  let(:locator) { described_class.new }

  before do
    allow(described_class::RATE_LIMITER).to receive(:with_rate_limit).and_yield
    Geocoder::Lookup::Test.set_default_stub([]) # anything not stubbed finds nothing
  end
  after { Geocoder::Lookup::Test.reset }

  def stub_place(query, latitude: 51.5076, longitude: -0.108, place_rank: 30, city: 'London', country: 'United Kingdom')
    Geocoder::Lookup::Test.add_stub(query, [ {
      'latitude' => latitude, 'longitude' => longitude, 'coordinates' => [ latitude, longitude ],
      'place_rank' => place_rank, 'city' => city, 'country' => country, 'address' => "Somewhere, #{city}, #{country}"
    } ])
  end

  let(:big_belly) do
    { name: 'Big Belly Comedy', address: 'Unit 6 & 7, 30 Stamford St', city: 'London', country: 'United Kingdom',
      latitude: nil, longitude: nil, postcode: 'SE1 9LQ', country_code: 'GB' }
  end

  it 'finds coordinates from the full address' do
    stub_place('Unit 6 & 7, 30 Stamford St, London, SE1 9LQ')

    expect(locator.call(big_belly)).to include(latitude: 51.5076, longitude: -0.108)
  end

  it 'drops the first part of the address, then tries the postcode' do
    stub_place('SE1 9LQ', latitude: 51.5075, longitude: -0.1069, place_rank: 23)

    expect(locator.call(big_belly)).to include(latitude: 51.5075, longitude: -0.1069)
  end

  it 'won’t put a pin on anything vaguer than a postcode' do
    stub_place('30 Stamford St, London, SE1 9LQ', place_rank: 16)

    expect(locator.call(big_belly)).to include(latitude: nil, longitude: nil)
  end

  describe 'with a postcode to check against' do
    before { stub_place('SE1 9LQ', latitude: 51.5075, longitude: -0.1069, place_rank: 23) }

    it 'takes an address match near the postcode' do
      stub_place('30 Stamford St, London, SE1 9LQ', latitude: 51.5078, longitude: -0.1069)

      expect(locator.call(big_belly)).to include(latitude: 51.5078)
    end

    it 'won’t use a postcode that’s in another city' do
      stub_place('SE1 9LQ', place_rank: 23, city: 'Marmaris')

      expect(locator.call(big_belly)).to include(latitude: nil)
    end

    it 'turns down a same-named street across the country, using the postcode instead' do
      stub_place('Unit 6 & 7, 30 Stamford St, London, SE1 9LQ', latitude: 54.1350, longitude: -0.7997)

      expect(locator.call(big_belly)).to include(latitude: 51.5075, longitude: -0.1069)
    end
  end

  it 'matches the city as a whole word' do
    stub_place('30 Stamford St, London, SE1 9LQ', city: 'Londonderry')

    expect(locator.call(big_belly)).to include(latitude: nil)
  end

  it 'rejects a match in another city' do
    stub_place('30 Stamford St, London, SE1 9LQ', city: 'Manchester')

    expect(locator.call(big_belly)).to include(latitude: nil)
  end

  it 'falls back on the venue’s name, for venues listed without an address' do
    stub_place('Drama Centre Theatre, Singapore', latitude: 1.2969, longitude: 103.8546, city: 'Singapore', country: 'Singapore')
    found = locator.call(name: 'Drama Centre Theatre', address: 'Singapore', city: 'Singapore', country: 'Singapore', country_code: 'SG')

    expect(found).to include(latitude: 1.2969, longitude: 103.8546)
  end

  it 'leaves out its hints, which aren’t venue attributes' do
    expect(locator.call(big_belly).keys).not_to include(:postcode, :country_code)
  end

  it 'fills in a missing city and country from the coordinates' do
    stub_place([ -23.5951, -46.6837 ], city: 'São Paulo', country: 'Brasil')
    found = locator.call(name: 'The Cavern Club', address: 'Rua Olimpíadas 360', city: nil, country: nil, latitude: -23.5951, longitude: -46.6837)

    expect(found).to include(city: 'São Paulo', country: 'Brasil')
  end

  it 'looks an address up only once a run' do
    allow(Geocoder).to receive(:search).and_call_original
    2.times { locator.call(big_belly) }

    expect(Geocoder).to have_received(:search).exactly(4).times # four queries, once each
  end

  it 'treats a failed lookup as not found' do
    allow(Geocoder).to receive(:search).and_raise(Timeout::Error)

    expect(locator.call(big_belly)).to include(latitude: nil)
  end
end
