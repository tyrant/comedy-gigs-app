require 'rails_helper'

RSpec.describe 'Revealing a venue deep in clusters', type: :system, js: true do
  # Venues ever closer to the Bull, so it's in a cluster inside a cluster
  # inside a cluster at country zoom
  let!(:bull) { create :venue, name: 'The Bull', city: 'London', latitude: 51.5, longitude: -0.1 }

  before do
    [ 0.002, 0.03, 0.3, 1.5 ].each_with_index do |offset, i|
      venue = create :venue, name: "Neighbour #{i}", city: 'London', latitude: 51.5 + offset, longitude: -0.1 + offset
      create :gig, venue:, start_time: 1.week.from_now, end_time: nil
    end
    create :gig, venue: bull, start_time: 1.week.from_now, end_time: nil
  end

  it 'zooms straight to it in one move, not a level at a time' do
    visit "#{root_path}?lat=52&lng=0&zoom=4"
    wait_for_map_ready
    page.execute_script(<<~JS)
      window.moves = 0;
      window.mapInstance.on('movestart', () => window.moves++);
    JS

    within('#venue-list') { click_on 'The Bull' }

    expect(page).to have_selector('.venue-marker[title="The Bull (1 gig)"]', wait: 10)
    page.document.synchronize(5) { raise Capybara::ExpectationNotMet, 'still moving' if page.evaluate_script('window.mapInstance.isMoving()') }
    expect(page.evaluate_script('window.mapInstance.getZoom()')).to be > 12
    expect(page.evaluate_script('window.moves')).to eq 1
  end
end
