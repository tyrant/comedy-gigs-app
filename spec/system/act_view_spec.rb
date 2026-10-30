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

  it 'credits a bio from Wikipedia' do
    guy.update!(description: nil, bio: 'Guy Montgomery is a New Zealand comedian.', bio_url: 'https://en.wikipedia.org/wiki/Guy_Montgomery')
    visit root_path(comedian: guy.id)

    within '#act-details' do
      expect(page).to have_text('Guy Montgomery is a New Zealand comedian.')
      expect(find_link('From Wikipedia (opens in a new tab)')[:href]).to eq 'https://en.wikipedia.org/wiki/Guy_Montgomery'
    end
  end

  it 'links to the act’s own sites' do
    guy.update!(social_links: { 'homepage' => 'https://guymontgomery.com/', 'instagram' => 'https://www.instagram.com/guymontgomery/' })
    visit root_path(comedian: guy.id)

    within '#act-details' do
      expect(all('[data-link-kind]').map { |link| link.text.squish }).to eq [ 'Website (opens in a new tab)', 'Instagram (opens in a new tab)' ]
      expect(find_link('Website (opens in a new tab)')[:href]).to eq 'https://guymontgomery.com/'
    end
  end

  it 'opens from a link, and closes with Escape' do
    visit root_path(comedian: guy.id)
    expect(page).to have_selector('#act-details h2', text: 'Guy Montgomery')
    expect(page).to have_button('All venues')

    find('#act-details h2').send_keys(:escape)
    expect(page).not_to have_selector('#act-details')
    expect(page).to have_selector('#venue-list')
  end

  it 'opens from an avatar in the act filter, leaving the menu shut' do
    visit root_path(act: rose.id)
    find('button[aria-label="Show Rose Matafeo’s gigs"]').click

    expect(page).to have_selector('#act-details h2', text: 'Rose Matafeo')
    expect(page).not_to have_selector('.react-select__menu')
    expect(current_url).to include "comedian=#{rose.id}"
  end

  it 'rings an avatar in light blue, and its ×, in light red, on hover' do
    visit root_path(act: rose.id)
    outline = ->(selector) { page.evaluate_script("getComputedStyle(document.querySelector('#{selector}')).outline") }

    avatar = find('button[aria-label="Show Rose Matafeo’s gigs"]')
    expect(outline.('.act-avatar')).to include 'none'
    avatar.hover
    expect(outline.('.act-avatar')).to include('3px', 'solid')

    find('.react-select__multi-value__remove').hover
    expect(outline.('.react-select__multi-value__remove')).to include('2px', 'solid')
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

  it 'searches just the act’s gigs, keeping the dates' do
    start, finish = Date.current.iso8601, 5.weeks.from_now.to_date.iso8601
    visit "#{root_path}?act=#{guy.id}&act=#{rose.id}&start=#{start}&end=#{finish}"
    expect(page).to have_selector('.react-select__multi-value', count: 2, wait: 10)
    click_venue_marker_and_wait_for_details('The Classic')
    within('#venue-details') { click_link 'Rose Matafeo' }

    within('#act-details') { click_button 'Search their gigs' }

    expect(page).to have_selector('.react-select__multi-value', count: 1)
    expect(page).to have_selector('.react-select__multi-value img[alt="Rose Matafeo"]')
    expect(page).to have_current_path(/act=#{rose.id}(?!.*act=)/, url: true)
    expect(current_url).to include("start=#{start}", "end=#{finish}")
    expect(find('#start_date', visible: :all).value).to eq start
    expect(page).to have_button('Searching their gigs', disabled: true)
    expect(page).to have_selector('#act-details h2', text: 'Rose Matafeo') # the act's view stays open
  end

  it 'brings the act’s gigs into view when searching them' do
    visit "#{root_path}?lat=51.5&lng=-0.1&zoom=6&comedian=#{rose.id}"
    wait_for_map_ready
    within('#act-details') { click_button 'Search their gigs' }

    expect(page).to have_selector('.venue-marker[title^="The Classic"]', wait: 10)
    page.document.synchronize(10) do
      lat = page.evaluate_script('window.mapInstance.getCenter().lat')
      raise Capybara::ExpectationNotMet, "map centre at #{lat}" unless lat.between?(-42, -36)
    end
  end
end
