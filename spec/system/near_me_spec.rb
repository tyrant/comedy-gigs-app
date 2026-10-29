require 'rails_helper'

RSpec.describe 'The near me button', type: :system, js: true do
  let!(:venue) { create :venue, name: 'The Classic', latitude: -36.85, longitude: 174.76 }
  let!(:gig) { create :gig, venue:, start_time: 1.week.from_now, end_time: nil }

  # Chrome, told where it is and allowed to say
  def place_browser_at(latitude, longitude)
    browser = page.driver.browser
    browser.execute_cdp('Browser.grantPermissions', permissions: [ 'geolocation' ])
    browser.execute_cdp('Emulation.setGeolocationOverride', latitude:, longitude:, accuracy: 50)
  end

  it 'centres the map on you, at about a city’s size, and shows where you are' do
    visit root_path
    wait_for_map_ready
    place_browser_at(-36.85, 174.76)

    find('button[title="Find my location"]').click

    expect(page).to have_selector('.maplibregl-user-location-dot', wait: 10)
    expect(page).to have_selector('.venue-marker[title="The Classic (1 gig)"]')
    expect(page).to have_current_path(/lat=-36\.85\d*&lng=174\.76\d*&zoom=12/, url: true, wait: 10)
  end
end
