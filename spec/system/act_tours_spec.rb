require 'rails_helper'

RSpec.describe 'An act’s tours', type: :system, js: true do
  let!(:greg) { create :act, name: 'Greg Davies' }
  let!(:sydney) { create :venue, name: 'State Theatre', city: 'Sydney', latitude: -33.87, longitude: 151.21 }
  let!(:brighton) { create :venue, name: 'Brighton Dome', city: 'Brighton', latitude: 50.82, longitude: -0.14 }
  let!(:oxford) { create :venue, name: 'New Theatre', city: 'Oxford', latitude: 51.75, longitude: -1.26 }

  let!(:legend_sydney) { create :gig, name: 'Greg Davies: Full Fat Legend', venue: sydney, acts: [ greg ], start_time: 1.week.from_now, end_time: nil }
  let!(:legend_brighton) { create :gig, name: 'Greg Davies - Full Fat Legend', venue: brighton, acts: [ greg ], start_time: 2.weeks.from_now, end_time: nil }
  let!(:apollo) { create :venue, name: 'Hammersmith Apollo', city: 'London', latitude: 51.49, longitude: -0.22 }
  let!(:legend_london) { create :gig, name: 'Greg Davies Full Fat Legend', venue: apollo, acts: [ greg ], start_time: 4.weeks.from_now, end_time: nil }
  let!(:gala) { create :gig, name: 'Charity Gala', venue: oxford, acts: [ greg ], start_time: 3.weeks.from_now, end_time: nil }

  before { TourFinder.call }

  def gig_names = all('#act-details [data-role="gig-name"]').map(&:text)
  def map_center = page.evaluate_script('(({ lat, lng }) => [ lat, lng ])(window.mapInstance.getCenter())')

  it 'lists the tour, and shows just its gigs on the map and in the list until it’s chosen again' do
    visit root_path(comedian: greg.id)
    wait_for_map_ready
    expect(gig_names).to eq [ 'Greg Davies: Full Fat Legend', 'Greg Davies - Full Fat Legend', 'Charity Gala', 'Greg Davies Full Fat Legend' ]

    find('#act-details [data-tour-id]', text: 'Full Fat Legend').click

    expect(page).to have_current_path(/tour=#{greg.tours.first.id}/, url: true)
    expect(page).to have_text('3 gigs on Full Fat Legend for these dates')
    expect(page).to have_selector('#act-details [data-role="gig-name"]', count: 3)
    expect(gig_names).to eq [ 'Greg Davies: Full Fat Legend', 'Greg Davies - Full Fat Legend', 'Greg Davies Full Fat Legend' ]
    expect(page).to have_no_selector('.venue-marker[title^="New Theatre"]', visible: true)
    expect(page).to have_selector('[data-tour-id][aria-current="true"]', text: 'Full Fat Legend')
    # Fitted to where most of it is, the UK, not halfway to Sydney
    page.document.synchronize(10) { raise Capybara::ExpectationNotMet unless map_center[0].between?(50, 52) && map_center[1].between?(-1, 0) }

    find('#act-details [data-tour-id]', text: 'Full Fat Legend').click
    expect(page).to have_no_current_path(/tour=/, url: true)
    expect(page).to have_selector('#act-details [data-role="gig-name"]', count: 4)
  end

  it 'opens from a link, and Escape goes back to all the act’s gigs, then closes the act' do
    visit root_path(comedian: greg.id, tour: greg.tours.first.id)
    expect(page).to have_text('3 gigs on Full Fat Legend')

    find('#act-details h2').send_keys(:escape)
    expect(page).to have_text('4 gigs for these dates')
    expect(page).to have_selector('#act-details')

    find('#act-details h2').send_keys(:escape)
    expect(page).to have_no_selector('#act-details')
  end

  it 'has no tours section for an act without any' do
    visit root_path(comedian: create(:act, name: 'Rose Matafeo').tap { |rose| create :gig, acts: [ rose ], venue: oxford }.id)
    expect(page).to have_selector('#act-details h2', text: 'Rose Matafeo')
    expect(page).to have_no_selector('[data-tour-id]')
  end
end
