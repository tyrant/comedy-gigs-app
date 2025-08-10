require 'rails_helper'

RSpec.describe 'Search Form Persistence', type: :system, js: true do
  let(:act1_name) { Faker::Creature::Horse.name }
  let(:act2_name) { Faker::Creature::Bird.implausible_common_name }
  let(:act3_name) { Faker::Creature::Cat.breed }
  let!(:act1) { create :act, name: act1_name }
  let!(:act2) { create :act, name: act2_name }
  let!(:act3) { create :act, name: act3_name }

  let(:venue1_name) { Faker::JapaneseMedia::StudioGhibli.movie }
  let(:venue2_name) { Faker::JapaneseMedia::Conan.character }
  let(:venue3_name) { Faker::JapaneseMedia::CowboyBebop.song }
  let!(:venue1) { create :venue, name: venue1_name, latitude: -37.7, longitude: 169.1 }
  let!(:venue2) { create :venue, name: venue2_name, latitude: -42.8, longitude: 174.2 }
  let!(:venue3) { create :venue, name: venue3_name, latitude: -47.9, longitude: 179.3 }

  let(:past_gig_name) { Faker::Games::ClashOfClans.troop }
  let!(:past_gig) { create :gig, name: past_gig_name,
                                 start_time: 2.weeks.ago,
                                 end_time: 2.weeks.ago + 2.hours,
                                 venue: venue1,
                                 acts: [ act1 ] }
  let(:current_gig_name) { Faker::Games::FinalFantasyXIV.character }
  let!(:current_gig) { create :gig, name: current_gig_name,
                                    start_time: Time.current,
                                    end_time: Time.current + 2.hours,
                                    venue: venue2,
                                    acts: [ act2 ] }
  let(:future_gig1_name) { Faker::Games::LeagueOfLegends.location }
  let!(:future_gig1) { create :gig, name: future_gig1_name,
                                    start_time: 2.weeks.from_now,
                                    end_time: 2.weeks.from_now + 2.hours,
                                    venue: venue3,
                                    acts: [ act1 ] }
  let(:future_gig2_name) { Faker::Games::Overwatch.hero }
  let!(:future_gig2) { create :gig, name: future_gig2_name,
                                    start_time: 4.weeks.from_now,
                                    end_time: 4.weeks.from_now + 2.hours,
                                    venue: venue1,
                                    acts: [ act3 ] }
  let(:far_future_gig_name) { Faker::Games::SuperSmashBros.fighter }
  let!(:far_future_gig) { create :gig, name: far_future_gig_name,
                                       start_time: 8.weeks.from_now,
                                       end_time: 8.weeks.from_now + 2.hours,
                                       venue: venue2,
                                       acts: [ act2 ] }

  before do
    visit root_path
    wait_for_map_ready
  end

  describe 'form values persistence across page reloads' do
    it 'persists start date filter value and maintains filtered results' do
      start_date = 1.week.ago

      set_date_via_picker('start_date', start_date)

      initial_markers_count = all('.leaflet-marker-icon').count

      # Get current URL with filter parameters
      current_url_with_params = current_url
      expect(current_url_with_params).to include 'start='

      visit current_url_with_params
      wait_for_map_ready

      # Verify start date field is populated
      expect(find_field('start_date').value).to eq start_date.strftime('%Y-%m-%d')

      # Verify same venues are displayed after reload
      reloaded_markers_count = all('.leaflet-marker-icon').count

      expect(reloaded_markers_count).to eq initial_markers_count
    end

    it 'persists end date filter value and maintains filtered results' do
      end_date = 2.weeks.from_now

      set_date_via_picker('end_date', end_date)

      initial_to_markers_count = all('.leaflet-marker-icon').count

      # Get current URL
      current_url_with_params = current_url
      expect(current_url_with_params).to include 'end='

      visit current_url_with_params
      wait_for_map_ready

      # Verify end date field is populated
      expect(find_field('end_date').value).to eq end_date.strftime('%Y-%m-%d')

      # Verify same venues are displayed after reload
      reloaded_to_markers_count = all('.leaflet-marker-icon').count
      expect(reloaded_to_markers_count).to eq initial_to_markers_count
    end

    it 'persists both start and end date filters' do
      start_date = 1.week.ago
      end_date = 1.week.from_now

      # Set both date filters using helpers
      set_date_via_picker('start_date', start_date)
      set_date_via_picker('end_date', end_date)

      both_date_markers_count = all('.leaflet-marker-icon').count

      # Get current URL
      current_url_with_params = current_url
      expect(current_url_with_params).to include 'start='
      expect(current_url_with_params).to include 'end='

      # Reload the page
      visit current_url_with_params
      wait_for_map_ready

      # Verify both date fields are populated
      expect(find_field('start_date').value).to eq(start_date.strftime('%Y-%m-%d'))
      expect(find_field('end_date').value).to eq(end_date.strftime('%Y-%m-%d'))

      # Verify same filtering is applied
      reloaded_both_markers_count = all('.leaflet-marker-icon').count

      expect(reloaded_both_markers_count).to eq both_date_markers_count
    end

    it 'persists act filter selection and maintains filtered results' do
      select_act_via_dropdown(act1_name)

      # Should show venues where act1 performs
      act_filter_markers_count = all('.leaflet-marker-icon').count

      current_url_with_params = current_url
      expect(current_url_with_params).to include 'act='

      # Reload the page
      visit current_url_with_params
      wait_for_map_ready

      # Verify act selection is maintained by checking if the act appears in selected values
      expect(page).to have_selector(".react-select__multi-value img[alt='#{act1_name}']", wait: 15)

      # Verify same venues are displayed
      reloaded_act_markers_count = all('.leaflet-marker-icon').count

      expect(reloaded_act_markers_count).to eq act_filter_markers_count
    end

    it 'persists combined filters (dates and act)' do
      start_date = Date.current

      set_date_via_picker('start_date', start_date)
      select_act_via_dropdown(act3_name)

      combined_filter_markers_count = all('.leaflet-marker-icon').count

      current_url_with_params = current_url
      expect(current_url_with_params).to include 'start='
      expect(current_url_with_params).to include 'act='

      visit current_url_with_params
      wait_for_map_ready

      # Verify all filters are maintained
      expect(find_field('start_date').value).to eq(start_date.strftime('%Y-%m-%d'))
      expect(page).to have_selector(".react-select__multi-value img[alt='#{act3_name}']", wait: 15)

      reloaded_combined_markers_count = all('.leaflet-marker-icon').count
      expect(reloaded_combined_markers_count).to eq(combined_filter_markers_count)

      # Click on venue to verify popup shows correct filtered gig
      first('.leaflet-marker-icon').click

      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup', wait: 10)
        expect(page).to have_selector("[data-act-id='#{act3.id}']")
      end
    end

    it 'maintains map position along with search filters' do
      start_date = 1.week.ago

      set_map_bounds_and_wait(-42.8, 174.2, 10)
      set_date_via_picker('start_date', start_date)

      current_url_with_params = current_url
      expect(current_url_with_params).to include 'start='
      expect(current_url_with_params).to include 'lat='
      expect(current_url_with_params).to include 'lng='
      expect(current_url_with_params).to include 'zoom='

      visit current_url_with_params
      wait_for_map_ready

      # Verify start date field is populated
      expect(find_field('start_date').value).to eq(start_date.strftime('%Y-%m-%d'))

      # Verify map position is maintained (approximately)
      map_center = page.evaluate_script('window.mapInstance ? window.mapInstance.getCenter() : null')
      expect(map_center).not_to be_nil
      expect(map_center['lat']).to be_within(0.1).of(-42.8)
      expect(map_center['lng']).to be_within(0.1).of(174.2)
    end

    it 'handles complex URL with all parameters after reload' do
      custom_start_date = 5.days.ago

      # Ensure clean state before starting
      reset_browser_state

      # Set multiple filters and map position
      set_map_bounds_and_wait(-40.0, 175.0, 8)
      set_date_via_picker('start_date', custom_start_date)
      select_act_via_dropdown(act2_name)

      # Wait for all changes to stabilize
      sleep 1

      # Capture initial state
      initial_markers_count = all('.leaflet-marker-icon').count
      current_url_with_params = current_url

      # Verify URL contains all expected parameters
      expect(current_url_with_params).to include 'start='
      expect(current_url_with_params).to include 'act='
      expect(current_url_with_params).to include 'lat='
      expect(current_url_with_params).to include 'lng='
      expect(current_url_with_params).to include 'zoom='

      # Reload with complex URL
      visit current_url_with_params
      wait_for_map_ready

      # Verify all form values are restored
      expect(find_field('start_date').value).to eq(custom_start_date.strftime('%Y-%m-%d'))

      # More robust check for act selection - check if any multi-value exists first
      if page.has_selector?('.react-select__multi-value', wait: 5)
        # Try multiple approaches to verify the act is selected
        act_selected = page.has_selector?(".react-select__multi-value img[alt='#{act2_name}']", wait: 10) ||
                      page.has_selector?(".react-select__multi-value", text: act2_name, wait: 10) ||
                      page.has_selector?(".react-select__multi-value-label", text: act2_name, wait: 10)

        expect(act_selected).to be_truthy, "Expected act '#{act2_name}' to be selected, but it wasn't found in multi-value selectors"
      else
        # If no multi-value found, check if the act dropdown shows the selection differently
        expect(page).to have_content(act2_name), "Expected to find act '#{act2_name}' somewhere on the page after reload"
      end

      # Verify same number of venues displayed (with some tolerance for timing)
      reloaded_markers_count = all('.leaflet-marker-icon').count
      expect(reloaded_markers_count).to eq(initial_markers_count),
        "Expected #{initial_markers_count} markers after reload, but found #{reloaded_markers_count}"

      # Verify map position maintained
      map_center = page.evaluate_script('window.mapInstance ? window.mapInstance.getCenter() : null')
      expect(map_center).not_to be_nil
      expect(map_center['lat']).to be_within(0.1).of(-40.0)
      expect(map_center['lng']).to be_within(0.1).of(175.0)
    end
  end
end
