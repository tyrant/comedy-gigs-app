require 'rails_helper'

RSpec.describe 'An act’s view', type: :system, js: true do
  let!(:rose) { create :act, name: 'Rose Matafeo', description: 'New Zealand comedian and actor.' }
  let!(:guy) { create :act, name: 'Guy Montgomery' }

  let!(:classic) { create :venue, name: 'The Classic', city: 'Auckland', latitude: -36.85, longitude: 174.76 }
  let!(:san_fran) { create :venue, name: 'San Fran', city: 'Wellington', latitude: -41.29, longitude: 174.78 }

  let!(:auckland_gig) { create :gig, name: 'Rose in Auckland', venue: classic, acts: [ rose, guy ], start_time: 1.week.from_now, end_time: nil }
  let!(:wellington_gig) { create :gig, name: 'Rose in Wellington', venue: san_fran, acts: [ rose ], start_time: 2.weeks.from_now, end_time: nil }
  let!(:guy_gig) { create :gig, name: 'Guy Alone', venue: san_fran, acts: [ guy ], start_time: 3.weeks.from_now, end_time: nil }

  def open_from_venue
    visit root_path
    wait_for_map_ready
    click_venue_marker_and_wait_for_details('The Classic')
    within('#venue-details') { click_link 'Rose Matafeo' }
    expect(page).to have_selector('#act-details h2', text: 'Rose Matafeo')
  end

  it 'opens from a venue’s lineup, with the act’s gigs everywhere, and goes back to the venue' do
    open_from_venue

    within '#act-details' do
      expect(page).to have_text('New Zealand comedian and actor.')
      expect(all('[data-role="gig-name"]').map(&:text)).to eq [ 'Rose in Auckland', 'Rose in Wellington' ]
      expect(page).to have_text('San Fran, Wellington')
      expect(page).not_to have_text('Guy Alone')
    end
    expect(page.evaluate_script('document.activeElement.textContent')).to eq 'Rose Matafeo'
    expect(current_url).to include "comedian=#{rose.id}"

    click_button 'Back to venue'
    expect(page).to have_selector('#venue-details h2', text: 'The Classic')
    expect(current_url).not_to include 'comedian='
  end

  it 'shows a gig on the map, keeping the act’s view open' do
    open_from_venue
    set_map_bounds_and_wait(-41.27, 174.74, 12) # San Fran in view, off centre
    expect(page).to have_selector(".venue-marker[data-venue-id='#{san_fran.id}']")
    within('#act-details') { click_link 'Rose in Wellington' }

    expect(page).to have_current_path(/lat=-41\.29\d*&lng=174\.78/, url: true, wait: 10)
    expect(page).to have_selector(".venue-marker.is-selected[data-venue-id='#{san_fran.id}']", wait: 10)
    expect(page).to have_selector("#act-details [data-gig-id='#{wellington_gig.id}'][aria-current]")
    expect(current_url).to include("venue=#{san_fran.id}").and include("gig=#{wellington_gig.id}")

    click_button 'Back to venue'
    expect(page).to have_selector('#venue-details h2', text: 'San Fran')
  end

  it 'opens from a link, and closes with Escape' do
    visit root_path(comedian: guy.id)
    expect(page).to have_selector('#act-details h2', text: 'Guy Montgomery')
    expect(page).to have_button('All venues')

    find('#act-details h2').send_keys(:escape)
    expect(page).not_to have_selector('#act-details')
    expect(page).to have_selector('#venue-list')
  end

  it 'shows a gig whose venue the act filter leaves off the map' do
    christchurch = create :venue, name: 'The Loons', city: 'Christchurch', latitude: -43.53, longitude: 172.64
    create :gig, name: 'Rose in Christchurch', venue: christchurch, acts: [ rose ], start_time: 4.weeks.from_now, end_time: nil

    visit root_path(act: guy.id, comedian: rose.id)
    wait_for_map_ready
    set_map_bounds_and_wait(-43.53, 172.64, 12)
    expect(page).not_to have_selector('.venue-marker')

    set_map_bounds_and_wait(-41, 174, 5)
    within('#act-details') { click_link 'Rose in Christchurch' }
    expect(page).to have_current_path(/lat=-43\.53\d*&lng=172\.64/, url: true, wait: 10)
  end
end
