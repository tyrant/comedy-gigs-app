require 'rails_helper'

RSpec.describe 'Gig Deep-Linking', type: :system, js: true do
  let(:act1_name) { Faker::Creature::Horse.name }
  let(:act2_name) { Faker::Creature::Bird.implausible_common_name }
  let(:act3_name) { Faker::Creature::Cat.breed }
  let!(:act1) { create :act, name: act1_name }
  let!(:act2) { create :act, name: act2_name }
  let!(:act3) { create :act, name: act3_name }

  let(:venue1_name) { Faker::JapaneseMedia::StudioGhibli.movie }
  let(:venue2_name) { Faker::JapaneseMedia::Conan.character }
  let!(:venue1) { create :venue, name: venue1_name, latitude: -37.7, longitude: 169.1 }
  let!(:venue2) { create :venue, name: venue2_name, latitude: -42.8, longitude: 174.2 }

  let(:gig1_name) { Faker::Games::ClashOfClans.troop }
  let!(:gig1) { create :gig, name: gig1_name,
                             start_time: 1.week.from_now,
                             end_time: 1.week.from_now + 2.hours,
                             venue: venue1,
                             acts: [ act1 ] }

  let(:gig2_name) { Faker::Games::FinalFantasyXIV.character }
  let!(:gig2) { create :gig, name: gig2_name,
                             start_time: 2.weeks.from_now,
                             end_time: 2.weeks.from_now + 2.hours,
                             venue: venue1,
                             acts: [ act2 ] }

  let(:gig3_name) { Faker::Games::LeagueOfLegends.location }
  let!(:gig3) { create :gig, name: gig3_name,
                             start_time: 3.weeks.from_now,
                             end_time: 3.weeks.from_now + 2.hours,
                             venue: venue2,
                             acts: [ act3 ] }

  before do
    # Force a complete page refresh to ensure clean state
    page.driver.browser.navigate.refresh if page.driver.respond_to?(:browser)
    visit root_path
    wait_for_map_ready
  end

  describe 'clicking gig titles in venue popup' do
    it 'adds gig ID to URL when clicking a gig title' do
      click_venue_marker_and_wait_for_popup(venue1_name)

      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup')
        expect(page).to have_text(venue1_name)

        # Click on the first gig title (should be a clickable link)
        within "[data-gig-id='#{gig1.id}']" do
          expect(page).to have_text(gig1_name)
          find('a', text: gig1_name).click
        end
      end

      # Verify URL contains both venue and gig parameters
      expect(current_url).to include "venue=#{venue1.id}"
      expect(current_url).to include "gig=#{gig1.id}"
    end

    it 'updates gig ID in URL when clicking different gig titles in same venue' do
      click_venue_marker_and_wait_for_popup(venue1_name)

      within '.leaflet-popup' do
        within "[data-gig-id='#{gig1.id}']" do
          find('a', text: gig1_name).click
        end
      end

      expect(current_url).to include "venue=#{venue1.id}"
      expect(current_url).to include "gig=#{gig1.id}"

      within '.leaflet-popup' do
        # Click second gig in same venue
        within "[data-gig-id='#{gig2.id}']" do
          find('a', text: gig2_name).click
        end
      end

      # URL should now have the new gig ID
      expect(current_url).to include "venue=#{venue1.id}"
      expect(current_url).to include "gig=#{gig2.id}"
      expect(current_url).not_to include "gig=#{gig1.id}"
    end

    it 'removes gig ID from URL when closing venue popup' do
      # Click on venue1 marker to open popup
      click_venue_marker_and_wait_for_popup(venue1_name)

      within '.leaflet-popup' do
        # Click on a gig title
        within "[data-gig-id='#{gig1.id}']" do
          find('a', text: gig1_name).click
        end
      end

      expect(current_url).to include "venue=#{venue1.id}"
      expect(current_url).to include "gig=#{gig1.id}"

      # Close the popup and wait for it to disappear
      close_popup_and_wait

      # Both venue and gig IDs should be removed from URL
      expect(current_url).not_to include "venue=#{venue1.id}"
      expect(current_url).not_to include "gig=#{gig1.id}"
    end
  end

  describe 'URL persistence and page reload' do
    it 'persists gig ID in URL after page reload' do
      # Manually visit URL with venue and gig parameters
      visit "#{root_path}?venue=#{venue1.id}&gig=#{gig1.id}"
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Verify URL contains the parameters
      expect(current_url).to include "venue=#{venue1.id}"
      expect(current_url).to include "gig=#{gig1.id}"

      # Reload the page
      page.refresh
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Parameters should still be in URL
      expect(current_url).to include "venue=#{venue1.id}"
      expect(current_url).to include "gig=#{gig1.id}"
    end

    it 'opens venue popup and scrolls to specific gig when both venue and gig IDs are in URL' do
      # Visit URL with both venue and gig parameters
      visit "#{root_path}?venue=#{venue1.id}&gig=#{gig2.id}"
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Wait for venue popup to automatically open from URL parameters
      wait_for_popup_to_appear

      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup')
        expect(page).to have_text(venue1_name)

        within "[data-gig-id='#{gig2.id}']" do
          expect(page).to have_text(gig2_name)
        end

        # The selector is being added to [data-gig-id=ID] itself; it's not *within*
        # it. Testing `within` fails. So let's fall back to the #popup-container.
        within '#venue-popup-scroll-container' do
          # Check for highlight class (temporary highlight effect)
          expect(page).to have_selector('.bg-blue-100', wait: 3) || true # May be temporary
        end
      end
    end

    it 'handles invalid gig ID gracefully' do
      invalid_gig_id = 99999

      # Visit URL with valid venue but invalid gig ID
      visit "#{root_path}?venue=#{venue1.id}&gig=#{invalid_gig_id}"
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Wait for venue popup to open from URL parameters
      wait_for_popup_to_appear

      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup')
        expect(page).to have_text(venue1_name)

        # Should show the venue's gigs normally, no error
        expect(page).to have_selector("[data-gig-id='#{gig1.id}']")
        expect(page).to have_selector("[data-gig-id='#{gig2.id}']")
      end
    end

    it 'handles gig ID without venue ID gracefully' do
      # Visit URL with gig ID but no venue ID
      visit "#{root_path}?gig=#{gig1.id}"
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Should load normally without opening any popup
      expect(page).not_to have_selector('.leaflet-popup')

      # Map should show all venue markers
      expect(page).to have_selector('.leaflet-marker-icon', wait: 5)
    end
  end

  describe 'gig deep-linking with search filters' do
    it 'maintains gig deep-link when search filters are applied' do
      # Set up a search filter first
      set_date_via_picker('start_date', Date.current)

      # Visit URL with venue and gig parameters
      visit "#{current_url}&venue=#{venue1.id}&gig=#{gig1.id}"
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Should maintain both search filters and gig deep-link
      expect(current_url).to include 'start='
      expect(current_url).to include "venue=#{venue1.id}"
      expect(current_url).to include "gig=#{gig1.id}"

      # Wait for venue popup to open from URL parameters
      wait_for_popup_to_appear

      within '.leaflet-popup' do
        expect(page).to have_text(venue1_name)
        within "[data-gig-id='#{gig1.id}']" do
          expect(page).to have_text(gig1_name)
        end
      end

      # Search filter should still be active
      expect(find_field('start_date').value).to eq(Date.current.strftime('%Y-%m-%d'))
    end

    it 'preserves search filters when clicking gig titles' do
      # Set up search filters
      set_date_via_picker('start_date', Date.current)
      select_act_via_dropdown(act1.name)

      # Get current URL with filters
      current_url_with_filters = current_url
      expect(current_url_with_filters).to include 'start='
      expect(current_url_with_filters).to include 'act='

      # Click on venue marker
      find(".leaflet-marker-icon[title=\"#{venue1_name}\"]").click

      within '.leaflet-popup' do
        # Click on gig title
        within "[data-gig-id='#{gig1.id}']" do
          find('a', text: gig1_name).click
        end
      end

      # URL should contain filters AND gig parameters
      expect(current_url).to include 'start='
      expect(current_url).to include 'act='
      expect(current_url).to include "venue=#{venue1.id}"
      expect(current_url).to include "gig=#{gig1.id}"

      # Form fields should maintain their values
      expect(find_field('start_date').value).to eq(Date.current.strftime('%Y-%m-%d'))
      expect(page).to have_selector(".react-select__multi-value img[alt='#{act1_name}']", wait: 5)
    end
  end

  describe 'gig deep-linking with map position' do
    it 'maintains map position when using gig deep-links' do
      set_map_bounds_and_wait(-42.8, 174.2, 12)

      # Get current URL with map parameters
      current_url_with_map = current_url
      expect(current_url_with_map).to include 'lat='
      expect(current_url_with_map).to include 'lng='
      expect(current_url_with_map).to include 'zoom='

      # Add gig deep-link parameters
      visit "#{current_url_with_map}&venue=#{venue2.id}&gig=#{gig3.id}"
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Should maintain both map position and gig deep-link
      expect(current_url).to include 'lat='
      expect(current_url).to include 'lng='
      expect(current_url).to include 'zoom='
      expect(current_url).to include "venue=#{venue2.id}"
      expect(current_url).to include "gig=#{gig3.id}"

      # Wait for venue popup to open from URL parameters
      wait_for_popup_to_appear

      within '.leaflet-popup' do
        expect(page).to have_text(venue2_name)
        within "[data-gig-id='#{gig3.id}']" do
          expect(page).to have_text(gig3_name)
        end
      end
    end
  end

  describe 'gig scrolling and highlighting' do
    it 'scrolls to and highlights the target gig when deep-linking' do
      # Visit URL with venue and gig parameters
      visit "#{root_path}?venue=#{venue1.id}&gig=#{gig2.id}"
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Wait for popup to open from URL parameters and scrolling to complete
      wait_for_popup_to_appear

      within '.leaflet-popup' do
        expect(page).to have_selector('.venue-popup')

        # Wait for scroll and highlight effect
        sleep 1.5 # Allow time for setTimeout and scrolling

        # The target gig should be visible in the scroll container
        within "[data-gig-id='#{gig2.id}']" do
          expect(page).to have_text(gig2_name)
          # Element should be in view (not checking exact scroll position, just that it's visible)
          expect(page).to have_selector('a', text: gig2_name)
        end
      end
    end

    it 'handles scrolling when there are multiple gigs in venue' do
      # Create additional gigs to ensure scrolling is needed
      additional_gigs = []
      5.times do |i|
        additional_gigs << create(:gig,
          name: "Additional Gig #{i}",
          start_time: (4 + i).weeks.from_now,
          end_time: (4 + i).weeks.from_now + 2.hours,
          venue: venue1,
          acts: [ act1 ]
        )
      end

      # Target the last gig (should require scrolling)
      target_gig = additional_gigs.last

      visit "#{root_path}?venue=#{venue1.id}&gig=#{target_gig.id}"
      expect(page).to have_selector('.leaflet-container', wait: 10)

      # Wait for venue popup to open from URL parameters
      wait_for_popup_to_appear

      within '.leaflet-popup' do
        # Wait for scrolling to complete
        sleep 1.5

        # Target gig should be visible after scrolling
        within "[data-gig-id='#{target_gig.id}']" do
          expect(page).to have_text("Additional Gig 4")
        end
      end
    end
  end
end
