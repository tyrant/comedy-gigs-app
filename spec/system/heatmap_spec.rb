require 'rails_helper'

RSpec.describe 'The gig heatmap', type: :system, js: true do
  let!(:classic) { create :venue, name: 'The Classic', latitude: -36.85, longitude: 174.76 }
  let!(:san_fran) { create :venue, name: 'San Fran', latitude: -41.29, longitude: 174.78 }
  let!(:busy) { create_list :gig, 3, venue: classic, start_time: 1.week.from_now, end_time: nil }
  let!(:quiet) { create :gig, venue: san_fran, start_time: 1.week.from_now, end_time: nil }

  # The heatmap's venues and their gig counts, once its source has them
  def heat_venues
    result = nil
    page.document.synchronize(10) do
      result = page.evaluate_script(<<~JS)
        (() => {
          const map = window.mapInstance;
          if (!map?.getLayer('venue-heat') || !map.isSourceLoaded('venue-heat')) return null;
          return map.querySourceFeatures('venue-heat').map(f => [ f.properties.name, f.properties.gigs ]);
        })()
      JS
      raise Capybara::ExpectationNotMet, 'heatmap not ready' if result.blank?
    end
    result.uniq.sort
  end

  it 'weighs the venues by their gigs, and survives a change of theme' do
    visit "#{root_path}?lat=-39&lng=175&zoom=5"
    wait_for_map_ready
    expect(heat_venues).to eq [ [ 'San Fran', 1 ], [ 'The Classic', 3 ] ]

    click_button 'Switch to dark mode' # a whole new basemap style
    expect(page).to have_button('Switch to light mode')
    expect(heat_venues).to eq [ [ 'San Fran', 1 ], [ 'The Classic', 3 ] ]
  end
end
