require 'rails_helper'

RSpec.describe 'Search Form Filtering', type: :system, js: true do
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

  describe 'start_date filtering' do
    it 'filters venues and gigs based on start_date' do
      # Filters out past_gig only.
      set_date_via_picker('start_date', 1.week.ago)

      # Should show venues with current/future gigs (venue2, venue3, venue1).
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue1_name} (1 gig)\"]", wait: 15)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue2_name} (2 gigs)\"]", wait: 15)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue3_name} (1 gig)\"]", wait: 15)

      # Click on venue1 marker
      find(".leaflet-marker-icon[title=\"#{venue1_name} (1 gig)\"]").click

      # Venue1's gigs: future_gig2 (hosted by act3) but not past_gig (hosted by act1).
      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup', wait: 10)
        expect(page).to have_text(venue1_name)

        within "[data-act-id='#{act3.id}']" do
          expect(page).to have_text(act3_name)
        end
        within "[data-gig-id='#{future_gig2.id}']" do
          expect(page).to have_text(future_gig2_name)
        end

        expect(page).not_to have_selector("[data-gig-id='#{past_gig.id}']")
      end
    end

    it 'shows all venues when start_date is in the past' do
      set_date_via_picker('start_date', 3.weeks.ago)

      # Should show all venue markers
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue1_name} (2 gigs)\"]", wait: 15)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue2_name} (2 gigs)\"]", wait: 15)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue3_name} (1 gig)\"]", wait: 15)
    end

    it 'hides venues when start_date is in the future' do
      set_date_via_picker('start_date', 10.weeks.from_now)

      # Should show no venue markers (all gigs are before this date)
      # Wait for markers to be removed
      sleep 2
      expect(page).not_to have_selector('.leaflet-marker-icon', wait: 15)
    end
  end

  describe 'end_date filtering' do
    it 'filters venues and gigs based on end_date' do
      # Before setting end_date: date range (Today..1.year_from_now).
      # Shows: current_gig, future_gig1, future_gig2, far_future_gig.
      #
      # After: date range (Today..3.weeks.from_now).
      # Excludes: future_gig2 (4.weeks), and far_future_gig (8.weeks).
      # Gigs: current_gig (Today), future_gig1 (2.weeks).
      # Venues: venue2, venue3.

      set_date_via_picker('end_date', 3.weeks.from_now)

      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue1_name}\"]", wait: 15)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue2_name} (1 gig)\"]", wait: 15)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue3_name} (1 gig)\"]", wait: 15)

      find(".leaflet-marker-icon[title=\"#{venue2_name} (1 gig)\"]").click

      # Venue2 shows current_gig (hosted by act2) but not far_future_gig (hosted by act2).
      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup', wait: 10)
        expect(page).to have_text(venue2_name)

        within "[data-act-id='#{act2.id}']" do
          expect(page).to have_text(act2_name)
        end
        within "[data-gig-id='#{current_gig.id}']" do
          expect(page).to have_text(current_gig_name)
        end

        expect(page).not_to have_selector("[data-gig-id='#{far_future_gig.id}']")
      end
    end

    it 'hides all venues when end_date is in the past' do
      set_date_via_picker('end_date', 1.month.ago)

      # Should show no venues since all gigs are after the end_date
      # Wait for markers to be removed
      sleep 2
      expect(page).not_to have_selector('.leaflet-marker-icon', wait: 15)

      # Specifically verify no venue markers are present
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue1_name}\"]")
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue2_name}\"]")
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue3_name}\"]")
    end
  end

  describe 'Combined From and To date filtering' do
    it 'filters venues with gigs within date range' do
      set_date_via_picker('start_date', 1.week.ago)
      set_date_via_picker('end_date', 3.weeks.from_now)

      # Should show venue markers with gigs within the date range
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue1_name}\"]", wait: 15)

      # Should show venues with gigs in the specified range
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue2_name} (1 gig)\"]", wait: 15) # current_gig
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue3_name} (1 gig)\"]", wait: 15) # future_gig1
    end

    it 'shows venues with multiple gigs when some are in range' do
      # Shows future_gig1 (at venue3), and future_gig2 (at venue1)
      set_date_via_picker('start_date', 1.week.from_now)
      set_date_via_picker('end_date', 5.weeks.from_now)

      # Should show venue1 (has future_gig2 in range) and venue3 (has future_gig1 in range)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue1_name} (1 gig)\"]", wait: 15)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue3_name} (1 gig)\"]", wait: 15)

      # Click on venue1 to verify popup shows only gigs in range
      find(".leaflet-marker-icon[title=\"#{venue1_name} (1 gig)\"]").click

      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup', wait: 10)
        within "[data-act-id='#{act3.id}']" do
          expect(page).to have_text(act3_name)
        end
        within "[data-gig-id='#{future_gig2.id}']" do
          expect(page).to have_text(future_gig2.name)
        end

        expect(page).not_to have_selector("[data-gig-id='#{past_gig.id}']")
      end
    end
  end

  describe 'Act filtering' do
    it 'shows only venues with gigs by selected act' do
      select_act_via_dropdown(act1.name)

      # Should show venues where act1 performs
      # Should show venue3 (has future_gig1 with act1)
      expect(page).to have_selector(".leaflet-marker-icon[title*=\"#{venue3_name} (1 gig)\"]", wait: 15)

      # Verify gig count is displayed correctly on the marker
      verify_marker_gig_count(venue3_name, 1)

      # Shouldn't show venue1 (act1 performs there but it's outside default date range)
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue1_name}\"]")
      # Shouldn't show venue2 anyway (act1 doesn't perform there)
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue2_name}\"]")
    end

    it 'shows venues with multiple acts when one is selected' do
      select_act_via_dropdown(act3.name)

      expect(page).to have_selector(".leaflet-marker-icon[title*=\"#{venue1_name} (1 gig)\"]", wait: 15)

      # Verify gig count is displayed correctly on the marker
      verify_marker_gig_count(venue1_name, 1)

      find(".leaflet-marker-icon[title*=\"#{venue1_name} (1 gig)\"]").click

      # Shows Venue1, gigged by Act3 but not Act1.
      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup', wait: 10)
        expect(page).to have_selector("[data-act-id=\"#{act3.id}\"]")
        expect(page).not_to have_selector("[data-act-id=\"#{act1.id}\"]")
      end
    end

    it 'combines act filtering with date filtering' do
      select_act_via_dropdown(act1.name)
      set_date_via_picker('start_date', Date.current)

      # Should show venues with Comedy Act 1 within the date range (venue3)
      expect(page).to have_selector(".leaflet-marker-icon[title=\"#{venue3_name} (1 gig)\"]", wait: 15) # future_gig1 with act1

      # Should not show venues outside criteria
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue1_name}\"]") # past_gig with act1 is outside date range
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue2_name}\"]") # has act2, not act1
    end
  end

  describe 'Venue marker gig count display' do
    it 'displays correct gig counts on venue markers' do
      # Initially shows venues with gigs in default date range
      # venue2: current_gig (1 gig)
      # venue3: future_gig1 (1 gig)
      # venue1: future_gig2 (1 gig)
      # venue2: far_future_gig (1 gig)
      # Note: venue1 and venue2 each have 2 gigs total, venue3 has 1 gig

      wait_for_marker_count(3) # Should show 3 venues

      # Verify gig counts are displayed correctly
      verify_all_marker_gig_counts({
        venue1_name => 1, # future_gig2 only (past_gig is outside default range)
        venue2_name => 2, # current_gig + far_future_gig
        venue3_name => 1  # future_gig1 only
      })
    end

    it 'updates gig counts when date range changes' do
      # Expand date range to include past gigs
      set_date_via_picker('start_date', 1.month.ago)

      wait_for_api_completion

      # Now venue1 should show 2 gigs (past_gig + future_gig2)
      verify_all_marker_gig_counts({
        venue1_name => 2, # past_gig + future_gig2
        venue2_name => 2, # current_gig + far_future_gig
        venue3_name => 1  # future_gig1 only
      })
    end

    it 'updates gig counts when filtering by acts' do
      # Filter by act1 - should show venues with act1 gigs only
      select_act_via_dropdown(act1.name)

      wait_for_api_completion

      # Should only show venue3 (future_gig1 with act1)
      # venue1's past_gig with act1 is outside default date range
      verify_marker_gig_count(venue3_name, 1)

      # Verify other venues are not shown
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue1_name}\"]")
      expect(page).not_to have_selector(".leaflet-marker-icon[title*=\"#{venue2_name}\"]")
    end

    it 'shows multiple gigs at same venue with correct count' do
      # Expand date range to show all gigs
      set_date_via_picker('start_date', 1.month.ago)
      set_date_via_picker('end_date', 3.months.from_now)

      wait_for_api_completion

      # venue1 has 2 gigs: past_gig + future_gig2
      # venue2 has 2 gigs: current_gig + far_future_gig
      # venue3 has 1 gig: future_gig1
      verify_all_marker_gig_counts({
        venue1_name => 2,
        venue2_name => 2,
        venue3_name => 1
      })

      # Click on venue1 to verify popup shows both gigs
      click_venue_marker_and_wait_for_popup(venue1_name)

      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup', wait: 10)
        # Should show both gigs for venue1
        expect(page).to have_content(past_gig_name)
        expect(page).to have_content(future_gig2_name)
      end
    end
  end
end
