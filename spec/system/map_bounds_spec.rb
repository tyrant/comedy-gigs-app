require 'rails_helper'

RSpec.describe 'Map Bounds Functionality', type: :system, js: true do
  let!(:act1) { create(:act, name: 'Comedy Act 1') }
  let!(:act2) { create(:act, name: 'Comedy Act 2') }

  # Create venues at different global locations
  let!(:venue_london) { create(:venue, name: 'London Comedy Club', latitude: 51.5074, longitude: -0.1278) }
  let!(:venue_nyc) { create(:venue, name: 'NYC Comedy Club', latitude: 40.7128, longitude: -74.0060) }
  let!(:venue_sydney) { create(:venue, name: 'Sydney Comedy Club', latitude: -33.8688, longitude: 151.2093) }
  let!(:venue_tokyo) { create(:venue, name: 'Tokyo Comedy Club', latitude: 35.6762, longitude: 139.6503) }

  # Create gigs at these venues
  let!(:gig_london) { create(:gig, venue: venue_london, acts: [ act1 ], start_time: 1.week.from_now, end_time: 1.week.from_now + 2.hours) }
  let!(:gig_nyc) { create(:gig, venue: venue_nyc, acts: [ act2 ], start_time: 2.weeks.from_now, end_time: 2.weeks.from_now + 2.hours) }
  let!(:gig_sydney) { create(:gig, venue: venue_sydney, acts: [ act1 ], start_time: 3.weeks.from_now, end_time: 3.weeks.from_now + 2.hours) }
  let!(:gig_tokyo) { create(:gig, venue: venue_tokyo, acts: [ act2 ], start_time: 4.weeks.from_now, end_time: 4.weeks.from_now + 2.hours) }

  before do
    visit root_path
    # Wait for map to fully load
    expect(page).to have_selector('.leaflet-container', wait: 10)
    sleep 2 # Allow React components to mount
  end

  describe 'venue markers display based on map bounds' do
    it 'shows only London venue when zoomed to London area' do
      # Set map bounds to London area (tight zoom)
      page.execute_script(<<~JS)
        if (window.mapInstance) {
          window.mapInstance.setView([51.5074, -0.1278], 12);
          window.mapInstance.fire('moveend');
        }
      JS

      sleep 2 # Wait for debounced API call and marker updates

      # Should show London venue marker specifically
      expect(page).to have_selector('.leaflet-marker-icon[title="London Comedy Club"]', wait: 5)

      # Should not show other distant venues
      expect(page).not_to have_selector('.leaflet-marker-icon[title="NYC Comedy Club"]')
      expect(page).not_to have_selector('.leaflet-marker-icon[title="Sydney Comedy Club"]')
    end

    it 'shows only NYC venue when zoomed to NYC area' do
      page.execute_script(<<~JS)
        if (window.mapInstance) {
          window.mapInstance.setView([40.7128, -74.0060], 12);
          window.mapInstance.fire('moveend');
        }
      JS

      sleep 2

      # Should show NYC venue marker specifically
      expect(page).to have_selector('.leaflet-marker-icon[title="NYC Comedy Club"]', wait: 5)

      # Should not show other distant venues
      expect(page).not_to have_selector('.leaflet-marker-icon[title="London Comedy Club"]')
      expect(page).not_to have_selector('.leaflet-marker-icon[title="Sydney Comedy Club"]')
    end

    it 'shows Europe/US venues when zoomed to Atlantic view' do
      # Focus on Atlantic area to show London and NYC but not Asia-Pacific
      page.execute_script(<<~JS)
        if (window.mapInstance) {
          window.mapInstance.setView([45.0, -30.0], 4);
          window.mapInstance.fire('moveend');
        }
      JS

      sleep 2

      # Should show Atlantic venues (London and NYC)
      expect(page).to have_selector('.leaflet-marker-icon[title="London Comedy Club"]', wait: 5)
      expect(page).to have_selector('.leaflet-marker-icon[title="NYC Comedy Club"]', wait: 5)

      # Should not show Asia-Pacific venues at this zoom/location
      expect(page).not_to have_selector('.leaflet-marker-icon[title="Sydney Comedy Club"]')
      expect(page).not_to have_selector('.leaflet-marker-icon[title="Tokyo Comedy Club"]')
    end
  end

  describe 'map position persistence in URL' do
    it 'updates URL parameters when map position changes' do
      page.execute_script(<<~JS)
        if (window.mapInstance) {
          window.mapInstance.setView([51.5074, -0.1278], 10);
          window.mapInstance.fire('moveend');
        }
      JS

      sleep 1

      # Check URL contains map parameters
      expect(current_url).to match(/lat=51\.5074/)
      expect(current_url).to match(/lng=-0\.1278/)
      expect(current_url).to match(/zoom=10/)
    end

    it 'restores map position from URL parameters on page load' do
      # Visit with specific map parameters
      visit root_path + '?lat=40.7128&lng=-74.0060&zoom=12'

      expect(page).to have_selector('.leaflet-container', wait: 10)
      sleep 2

      # Verify map is positioned correctly
      lat = page.evaluate_script('window.mapInstance ? window.mapInstance.getCenter().lat : null')
      lng = page.evaluate_script('window.mapInstance ? window.mapInstance.getCenter().lng : null')
      zoom = page.evaluate_script('window.mapInstance ? window.mapInstance.getZoom() : null')

      expect(lat).to be_within(0.01).of(40.7128)
      expect(lng).to be_within(0.01).of(-74.0060)
      expect(zoom).to eq(12)
    end
  end

  describe 'venue popup content' do
    it 'displays correct venue information in popup' do
      # Set map to show London venue
      page.execute_script(<<~JS)
        if (window.mapInstance) {
          window.mapInstance.setView([51.5074, -0.1278], 12);
          window.mapInstance.fire('moveend');
        }
      JS

      sleep 2

      # Click on first venue marker
      first('.leaflet-marker-icon').click

      # Verify popup appears with venue information
      expect(page).to have_selector('.leaflet-popup', wait: 3)

      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup')
        expect(page).to have_text('Comedy Club') # Should show venue name
        expect(page).to have_text('Comedy Act 1') # Should show act name
      end
    end
  end
end
