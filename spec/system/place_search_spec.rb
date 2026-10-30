require 'rails_helper'

RSpec.describe 'Searching for a place', type: :system, js: true do
  let!(:san_fran) { create :venue, name: 'San Fran', city: 'Wellington', latitude: -41.29, longitude: 174.78 }
  let!(:gig) { create :gig, venue: san_fran, start_time: 1.week.from_now, end_time: nil }

  # Photon, answered in the page rather than over the network
  PHOTON_ANSWER = {
    type: 'FeatureCollection',
    features: [
      { type: 'Feature', geometry: { type: 'Point', coordinates: [ 174.7762, -41.2865 ] },
        properties: { osm_type: 'R', osm_id: 1, name: 'Wellington', type: 'city', state: 'Wellington', country: 'New Zealand',
                      extent: [ 174.6, -41.1, 174.95, -41.4 ] } },
      { type: 'Feature', geometry: { type: 'Point', coordinates: [ 75.36, 15.18 ] },
        properties: { osm_type: 'N', osm_id: 2, name: 'Wellington', type: 'locality', state: 'Karnataka', country: 'India' } }
    ]
  }.freeze

  # Nominatim's boundary for Wellington: a triangle will do
  WELLINGTON_BOUNDARY = {
    type: 'FeatureCollection',
    features: [
      { type: 'Feature', properties: { osm_id: 1 },
        geometry: { type: 'Polygon', coordinates: [ [ [ 174.6, -41.4 ], [ 174.95, -41.4 ], [ 174.8, -41.1 ], [ 174.6, -41.4 ] ] ] } }
    ]
  }.freeze

  def stub_photon
    page.execute_script(<<~JS, PHOTON_ANSWER.to_json, WELLINGTON_BOUNDARY.to_json)
      const [ answer, boundary ] = arguments;
      const realFetch = window.fetch;
      window.photonQueries = [];
      window.nominatimQueries = [];
      const json = (body) => Promise.resolve(new Response(body, { headers: { 'Content-Type': 'application/json' } }));
      window.fetch = (url, options) => {
        if (String(url).startsWith('https://photon.komoot.io/')) {
          window.photonQueries.push(String(url));
          return json(answer);
        }
        if (String(url).startsWith('https://nominatim.openstreetmap.org/')) {
          window.nominatimQueries.push(String(url));
          return json(boundary);
        }
        return realFetch(url, options);
      };
    JS
  end

  # The outline's geometry type, or nil for none
  def outline_type
    page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      window.mapInstance.getSource('place-outline').getData().then(data => done(data.geometry?.type || null));
    JS
  end

  def map_center = page.evaluate_script('(({ lat, lng }) => [ lat, lng ])(window.mapInstance.getCenter())')

  before do
    visit "#{root_path}?lat=51.5&lng=-0.1&zoom=6"
    wait_for_map_ready
    stub_photon
  end

  it 'offers matching places, and goes to the one chosen with the keyboard' do
    find('input[aria-label="Search places"]').send_keys('Wellington')

    expect(page).to have_selector('[role="option"]', count: 2)
    expect(page).to have_selector('[role="option"]', text: 'New Zealand')
    expect(page.evaluate_script('window.photonQueries.at(-1)')).to include('q=Wellington', 'lat=51.5', 'lon=-0.1', 'zoom=6', 'layer=city')

    find('input[aria-label="Search places"]').send_keys(:down, :enter)

    expect(page).to have_no_selector('[role="option"]')
    expect(page).to have_selector('.venue-marker[title="San Fran (1 gig)"]', wait: 10)
    lat, lng = map_center
    expect(lat).to be_within(0.2).of(-41.25)
    expect(lng).to be_within(0.2).of(174.78)
  end

  it 'outlines the chosen place, until the box’s × clears both' do
    input = find('input[aria-label="Search places"]')
    input.send_keys('Wellington')
    find('[role="option"]', text: 'New Zealand').click

    page.document.synchronize(10) { raise Capybara::ExpectationNotMet, 'no outline' unless outline_type == 'Polygon' }
    expect(page.evaluate_script('window.nominatimQueries.at(-1)')).to include('osm_ids=R1', 'polygon_geojson=1')
    expect(page.evaluate_script('window.mapInstance.getZoom()')).to be > 9 # filling the map with it

    find('button[aria-label="Clear place search"]').click
    expect(input.value).to eq ''
    expect(outline_type).to be_nil
    expect(page).to have_no_selector('button[aria-label="Clear place search"]')
  end

  it 'goes to a clicked place, and Escape clears the box' do
    input = find('input[aria-label="Search places"]')
    input.send_keys('Wellington')
    find('[role="option"]', text: 'India').click

    expect(page).to have_no_selector('[role="option"]')
    page.document.synchronize(10) { raise Capybara::ExpectationNotMet unless map_center[0].between?(14, 16.5) }

    input.click
    input.send_keys(:escape, :escape)
    expect(input.value).to eq ''
  end
end
