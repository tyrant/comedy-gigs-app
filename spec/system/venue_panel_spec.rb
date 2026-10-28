require 'rails_helper'

RSpec.describe 'Venue panel', type: :system, js: true do
  let!(:act) { create :act, name: 'Rose Matafeo' }

  let!(:busy_venue) { create :venue, name: 'The Classic', city: 'Auckland', latitude: -36.85, longitude: 174.76 }
  let!(:quiet_venue) { create :venue, name: 'San Fran', city: 'Wellington', latitude: -41.29, longitude: 174.78 }
  let!(:far_venue) { create :venue, name: 'Comedy Store', city: 'London', latitude: 51.51, longitude: -0.13 }

  let!(:soon_gig) { create :gig, name: 'Soon', venue: quiet_venue, acts: [ act ], start_time: 3.days.from_now, end_time: nil }
  let!(:later_gigs) do
    [ 2, 3 ].map { |weeks| create :gig, name: "Later #{weeks}", venue: busy_venue, acts: [ act ], start_time: weeks.weeks.from_now, end_time: nil }
  end
  let!(:london_gig) { create :gig, venue: far_venue, acts: [ act ], start_time: 1.week.from_now, end_time: nil }

  before do
    visit root_path
    wait_for_map_ready
  end

  def list_entries = all('#venue-list [data-venue-id]').map(&:text)

  describe 'the list of venues in view' do
    it 'lists only the venues on screen, busiest first, with their towns' do
      expect(list_entries).to eq [ "The Classic\nAuckland\n2 gigs", "San Fran\nWellington\n1 gig" ]
      expect(page).to have_text('3 gigs at 2 venues in view')
    end

    it 'follows the map' do
      set_map_bounds_and_wait(51.51, -0.13, 9)

      expect(page).to have_text('1 gig at 1 venue in view')
      expect(list_entries).to eq [ "Comedy Store\nLondon\n1 gig" ]
    end

    it 'picks out the venue’s marker while hovering over its entry' do
      find("#venue-list [data-venue-id='#{quiet_venue.id}']").hover

      expect(page).to have_selector(".venue-marker.is-hovered[data-venue-id='#{quiet_venue.id}']")
    end
  end

  describe 'opening a venue' do
    it 'shows its gigs, moves focus to its name and marks its marker' do
      find("#venue-list [data-venue-id='#{busy_venue.id}']").click

      within '#venue-details' do
        expect(page).to have_selector('h2', text: 'The Classic')
        expect(page).to have_selector('[data-gig-id]', count: 2)
      end
      expect(page.evaluate_script('document.activeElement.textContent')).to eq 'The Classic'
      expect(page).to have_selector(".venue-marker.is-selected[data-venue-id='#{busy_venue.id}']")
      expect(current_url).to include "venue=#{busy_venue.id}"
    end

    it 'goes back to the list, with focus on the venue it came from' do
      find("#venue-list [data-venue-id='#{busy_venue.id}']").click
      close_venue_and_wait

      expect(page).to have_selector('#venue-list')
      expect(page.evaluate_script('document.activeElement.dataset.venueId')).to eq busy_venue.id.to_s
      expect(current_url).not_to include 'venue='
    end

    it 'closes with Escape' do
      click_venue_marker_and_wait_for_details('San Fran')
      find('#venue-details h2').send_keys(:escape)

      expect(page).not_to have_selector('#venue-details')
      expect(current_url).not_to include 'venue='
    end

    it 'zooms in to split the venue out of a cluster' do
      set_map_bounds_and_wait(-39, 175, 2) # Auckland and Wellington cluster together out here
      expect(page).to have_selector('.cluster-marker')
      expect(page).not_to have_selector('.venue-marker')

      find("#venue-list [data-venue-id='#{quiet_venue.id}']").click

      expect(page).to have_selector(".venue-marker.is-selected[data-venue-id='#{quiet_venue.id}']", wait: 10)
    end
  end

  describe 'date presets' do
    it 'sets both dates from the menu' do
      select 'Next 7 days', from: 'date_preset'
      wait_for_api_completion

      expect(find_field('start_date').value).to eq Date.current.iso8601
      expect(find_field('end_date').value).to eq 6.days.from_now.to_date.iso8601
      expect(current_url).to include "end=#{6.days.from_now.to_date.iso8601}"
      expect(list_entries).to eq [ "San Fran\nWellington\n1 gig" ]
    end

    it 'shows Custom dates once the dates match no preset' do
      expect(page).to have_select('date_preset', selected: 'Next 12 months')

      set_date_via_picker('end_date', 10.days.from_now)

      expect(page).to have_select('date_preset', selected: 'Custom dates')
    end
  end
end
