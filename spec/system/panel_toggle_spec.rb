require 'rails_helper'

RSpec.describe 'Hiding the panel on a desktop', type: :system, js: true do
  let!(:san_fran) { create :venue, name: 'San Fran', city: 'Wellington', latitude: -41.29, longitude: 174.78 }

  before { create :gig, venue: san_fran, start_time: 1.week.from_now, end_time: nil }

  def map_width = page.evaluate_script('window.mapInstance.getContainer().clientWidth')

  it 'folds the list away, giving the map the room, and brings it back' do
    visit "#{root_path}?lat=-41.29&lng=174.78&zoom=10"
    wait_for_map_ready
    expect(page).to have_selector('#venue-list', text: 'San Fran')
    width = map_width

    click_button 'Hide list'
    expect(page).to have_no_selector('#venue-list')
    expect(page).to have_text('1 gig at 1 venue in view') # the top row stays
    page.document.synchronize(5) { raise Capybara::ExpectationNotMet, 'map not widened' unless map_width > width + 300 }

    click_button 'Show list'
    expect(page).to have_selector('#venue-list', text: 'San Fran')
  end

  it 'opens again when a venue is chosen' do
    visit "#{root_path}?lat=-41.29&lng=174.78&zoom=10"
    wait_for_map_ready
    click_button 'Hide list'

    click_venue_marker_and_wait_for_details('San Fran')
    expect(page).to have_button('Hide venue')
  end
end
