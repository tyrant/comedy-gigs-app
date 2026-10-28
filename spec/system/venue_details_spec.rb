require 'rails_helper'

RSpec.describe 'A venue’s details', type: :system, js: true do
  let(:zed) { create :act, name: 'Zed Zebra' }
  let(:abe) { create :act, name: 'Abe Aardvark' }
  let!(:venue) { create :venue, name: 'The Laugh Shack', latitude: -41.29, longitude: 174.78, website: 'https://laughshack.example',
                               images: { 'medium' => '/images/comedian_placeholder.png' } }

  let!(:soonest) { create :gig, venue:, name: 'Zed Live', acts: [ zed ], start_time: 1.week.from_now, end_time: nil,
                              ticket_url: 'https://tickets.example/zed' }
  let!(:latest) { create :gig, venue:, name: 'Abe Live', acts: [ abe ], start_time: 3.weeks.from_now, end_time: nil }
  let!(:unlisted) { create :gig, venue:, name: 'Open Mic', acts: [], start_time: 2.weeks.from_now, end_time: nil }

  before { page.driver.browser.local_storage.clear if page.driver.browser.respond_to?(:local_storage) }

  def gig_order = all('#venue-details [data-role="gig-name"]').map(&:text)

  def open_venue
    visit root_path
    wait_for_map_ready
    click_venue_marker_and_wait_for_details('The Laugh Shack')
  end

  it 'puts the way back above the photo, and links the venue’s website' do
    open_venue

    within '#venue-details' do
      back, photo = find('[data-action="close-venue"]'), find('.venue-gigs > img')
      expect(back.rect.y).to be < photo.rect.y
      link = find('[data-role="venue-website"]')
      expect(link[:href]).to eq 'https://laughshack.example/'
      expect(link[:title]).to eq 'laughshack.example'
    end
  end

  it 'says when the link is to the venue’s page on a listings site' do
    venue.update!(website: 'https://www.ticketmaster.co.nz/the-laugh-shack-tickets-wellington/venue/1')
    open_venue

    link = find('#venue-details [data-role="venue-website"]')
    expect(link[:title]).to eq 'on Ticketmaster'
    expect(link[:'aria-label']).to eq 'The Laugh Shack on Ticketmaster (opens in a new tab)'
  end

  it 'sorts by date, or by act with unlisted lineups last, and remembers the choice' do
    open_venue
    expect(gig_order).to eq [ 'Zed Live', 'Open Mic', 'Abe Live' ]

    click_button 'Act'
    expect(page).to have_css('[data-sort="act"][aria-pressed="true"]')
    expect(gig_order).to eq [ 'Abe Live', 'Zed Live', 'Open Mic' ]

    open_venue
    expect(gig_order).to eq [ 'Abe Live', 'Zed Live', 'Open Mic' ]
  end

  it 'gives each gig a compact ticket link' do
    open_venue
    link = find("[data-gig-id='#{soonest.id}'] [data-role='ticket-url']")
    expect(link[:'aria-label']).to eq 'Tickets for Zed Live (opens in a new tab)'
    expect(link.text).to eq '🎟️'
  end
end
