require 'rails_helper'

RSpec.describe 'Map Bounds Functionality', type: :system, js: true do
  let(:act1_name) { Faker::Sports::Volleyball.player }
  let(:act2_name) { Faker::Sports::Mountaineering.mountaineer }
  let!(:act1) { create :act, name: act1_name }
  let!(:act2) { create :act, name: act2_name }

  # Create venues at different global locations
  let(:venue_london_name) { Faker::Sports::Football.team }
  let(:venue_nyc_name) { Faker::Sports::Chess.player }
  let(:venue_sydney_name) { Faker::Sports::Basketball.team }
  let(:venue_tokyo_name) { Faker::Sport.summer_paralympics_sport }
  let!(:venue_london) { create :venue, name: venue_london_name,
                                       latitude: 51.5074,
                                       longitude: -0.1278 }
  let!(:venue_nyc) { create :venue, name: venue_nyc_name,
                                    latitude: 40.7128,
                                    longitude: -74.0060 }
  let!(:venue_sydney) { create :venue, name: venue_sydney_name,
                                       latitude: -33.8688,
                                       longitude: 151.2093 }
  let!(:venue_tokyo) { create :venue, name: venue_tokyo_name,
                                      latitude: 35.6762,
                                      longitude: 139.6503 }

  # Create gigs at these venues
  let!(:gig_london) { create :gig, start_time: 1.week.from_now,
                                   end_time: 1.week.from_now + 2.hours,
                                   venue: venue_london,
                                   acts: [ act1 ] }
  let!(:gig_nyc) { create :gig, start_time: 2.weeks.from_now,
                                end_time: 2.weeks.from_now + 2.hours,
                                venue: venue_nyc,
                                acts: [ act2 ] }
  let!(:gig_sydney) { create :gig, start_time: 3.weeks.from_now,
                                   end_time: 3.weeks.from_now + 2.hours,
                                   venue: venue_sydney,
                                   acts: [ act1 ] }
  let!(:gig_tokyo) { create :gig, start_time: 4.weeks.from_now,
                                  end_time: 4.weeks.from_now + 2.hours,
                                  venue: venue_tokyo,
                                  acts: [ act2 ] }

  before do
    visit root_path
    wait_for_map_ready
  end

  describe 'venue markers display based on map bounds' do
    it 'shows only London venue when zoomed to London area' do
      # Set map bounds to London area (tight zoom)
      set_map_bounds_and_wait(51.5074, -0.1278, 11)

      # Should show London venue marker specifically
      expect(page).to have_selector(".venue-marker[title=\"#{venue_london_name} (1 gig)\"]", wait: 15)

      # Should not show other distant venues
      expect(page).not_to have_selector(".venue-marker[title*=\"#{venue_nyc_name}\"]")
      expect(page).not_to have_selector(".venue-marker[title*=\"#{venue_sydney_name}\"]")
    end

    it 'shows only NYC venue when zoomed to NYC area' do
      set_map_bounds_and_wait(40.7128, -74.0060, 11)

      # Should show NYC venue marker specifically
      expect(page).to have_selector(".venue-marker[title=\"#{venue_nyc_name} (1 gig)\"]", wait: 15)

      # Should not show other distant venues
      expect(page).not_to have_selector(".venue-marker[title*=\"#{venue_london_name}\"]")
      expect(page).not_to have_selector(".venue-marker[title*=\"#{venue_sydney_name}\"]")
    end

    it 'shows Europe/US venues when zoomed to Atlantic view' do
      # Focus on Atlantic area to show London and NYC but not Asia-Pacific
      set_map_bounds_and_wait(45.0, -30.0, 3)

      # Should show Atlantic venues (London and NYC)
      expect(page).to have_selector(".venue-marker[title=\"#{venue_london_name} (1 gig)\"]", wait: 15)
      expect(page).to have_selector(".venue-marker[title=\"#{venue_nyc_name} (1 gig)\"]", wait: 15)

      # Should not show Asia-Pacific venues at this zoom/location
      expect(page).not_to have_selector(".venue-marker[title*=\"#{venue_sydney_name}\"]")
      expect(page).not_to have_selector(".venue-marker[title*=\"#{venue_tokyo_name}\"]")
    end
  end

  describe 'map position persistence in URL' do
    it 'updates URL parameters when map position changes' do
      set_map_bounds_and_wait(51.5074, -0.1278, 9)

      expect(current_url).to match(/lat=51\.5074/)
      expect(current_url).to match(/lng=-0\.1278/)
      expect(current_url).to match(/zoom=9/)
    end

    it 'restores map position from URL parameters on page load' do
      # Visit with specific map parameters
      visit root_path + '?lat=40.7128&lng=-74.0060&zoom=11'

      expect(page).to have_selector(".maplibregl-map", wait: 10)

      lat = page.evaluate_script('window.mapInstance ? window.mapInstance.getCenter().lat : null')
      lng = page.evaluate_script('window.mapInstance ? window.mapInstance.getCenter().lng : null')
      zoom = page.evaluate_script('window.mapInstance ? window.mapInstance.getZoom() : null')

      expect(lat).to be_within(0.01).of(40.7128)
      expect(lng).to be_within(0.01).of(-74.0060)
      expect(zoom).to eq(11)
    end
  end

  describe 'venue panel content' do
    it 'displays correct venue information in venue panel' do
      set_map_bounds_and_wait(51.5074, -0.1278, 11)

      first(".venue-marker").click

      expect(page).to have_selector("#venue-details", wait: 3)

      within "#venue-details" do
        expect(page).to have_selector(".venue-gigs")
        expect(page).to have_text(venue_london_name) # Should show venue name
        expect(page).to have_text(act1_name) # Should show act name
      end
    end
  end

  describe 'clustering' do
    let!(:venue_near_london) { create :venue, name: 'Down the Road', latitude: 51.52, longitude: -0.10 }
    let!(:gig_near_london) { create :gig, start_time: 5.weeks.from_now, end_time: 5.weeks.from_now + 2.hours,
                                          venue: venue_near_london, acts: [ act2 ] }

    it 'groups nearby venues and zooms in to split them when clicked' do
      # The outer before visited the page before these records existed
      visit "#{root_path}?lat=51.5&lng=-0.1&zoom=3"
      wait_for_map_ready

      cluster = find('.cluster-marker[aria-label="2 venues, 2 gigs; zoom in"]')
      expect(cluster).to have_text('2', exact: true)
      expect(cluster[:class].split).to include('size-9', 'is-few') # few venues, few gigs
      expect(cluster[:class].split).to include('maplibregl-marker') # MapLibre's class, which positions it
      expect(cluster.evaluate_script('getComputedStyle(this).position')).to eq 'absolute'
      expect(page).not_to have_selector(".venue-marker[title*=\"#{venue_london_name}\"]")

      cluster.click

      expect(page).to have_selector(".venue-marker[title=\"#{venue_london_name} (1 gig)\"]")
      expect(page).to have_selector('.venue-marker[title="Down the Road (1 gig)"]')
      expect(page.evaluate_script('window.mapInstance.getZoom()')).to be > 3
    end
  end
end
