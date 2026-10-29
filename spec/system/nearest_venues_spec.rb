require 'rails_helper'

RSpec.describe 'The nearest gigs, when none are in view', type: :system, js: true do
  let!(:classic) { create :venue, name: 'The Classic', city: 'Auckland', latitude: -36.85, longitude: 174.76 }
  let!(:san_fran) { create :venue, name: 'San Fran', city: 'Wellington', latitude: -41.29, longitude: 174.78 }

  before do
    [ classic, san_fran ].each { |venue| create :gig, venue:, start_time: 1.week.from_now, end_time: nil }
  end

  it 'lists the closest venues, nearest first, and opens one' do
    visit "#{root_path}?lat=-39.5&lng=176.9&zoom=10" # Napier: nothing here
    wait_for_map_ready

    within('#nearest-venues') do
      expect(all('[data-venue-id] .font-medium').map(&:text)).to eq [ 'San Fran', 'The Classic' ]
      expect(page).to have_text(/Wellington · [\d.]+ (km|mi) away/)
      click_button(text: 'San Fran')
    end

    expect(page).to have_selector('#venue-details h2', text: 'San Fran')
    expect(page).to have_selector('.venue-marker[title="San Fran (1 gig)"]', wait: 10)
  end
end
