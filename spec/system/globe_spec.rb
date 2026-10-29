require 'rails_helper'

RSpec.describe 'The globe', type: :system, js: true do
  let!(:london) { create :venue, name: 'Comedy Store', city: 'London', latitude: 51.51, longitude: -0.13 }
  let!(:auckland) { create :venue, name: 'The Classic', city: 'Auckland', latitude: -36.85, longitude: 174.76 }

  before do
    [ london, auckland ].each { |venue| create :gig, venue:, start_time: 1.week.from_now, end_time: nil }
  end

  def map_view = page.evaluate_script('(({ lat, lng }) => [ lat, lng ])(window.mapInstance.getCenter()).concat(window.mapInstance.getZoom())')

  # From 40°N the north pole is in view, so the map's bounds take in every
  # longitude and reach south past Auckland, though it's round the back
  it 'shows only the venues on the side facing you, zoomed right out' do
    visit "#{root_path}?lat=40&lng=-20&zoom=1"
    wait_for_map_ready

    expect(page.evaluate_script('window.mapInstance.getProjection().type')).to eq 'globe'
    expect(map_view.map { |n| n.round(2) }).to eq [ 40, -20, 1 ] # as asked, not pulled to the equator
    within('#venue-list') do
      expect(page).to have_text('Comedy Store')
      expect(page).not_to have_text('The Classic') # round the back
    end
    expect(page).to have_selector('.venue-marker[title="Comedy Store (1 gig)"]', visible: true)
    expect(page).to have_no_selector('.venue-marker[title="The Classic (1 gig)"]', visible: true)
  end

  it 'keeps the view through a change of theme' do
    visit "#{root_path}?lat=40&lng=-20&zoom=1"
    wait_for_map_ready

    click_button 'Switch to dark mode'
    expect(page).to have_button('Switch to light mode')
    page.document.synchronize(10) do # the new style loads in the background
      raise Capybara::ExpectationNotMet, 'style still loading' unless page.evaluate_script('window.mapInstance.isStyleLoaded()')
    end
    expect(map_view.map { |n| n.round(2) }).to eq [ 40, -20, 1 ]
  end
end
