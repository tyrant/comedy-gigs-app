require 'rails_helper'

RSpec.describe 'A gig’s calendar and share buttons', type: :system, js: true do
  let!(:venue) { create :venue, name: 'The Classic', city: 'Auckland', latitude: -36.85, longitude: 174.76 }
  let!(:gig) { create :gig, name: 'Late Show', venue:, start_time: 1.week.from_now, end_time: nil }

  before do
    visit root_path(venue: venue.id)
    expect(page).to have_selector('#venue-details h2', text: 'The Classic')
  end

  it 'offers the gig’s calendar file' do
    link = find("[data-gig-id='#{gig.id}'] [data-role='add-to-calendar']")
    expect(link[:href]).to end_with "/gigs/#{gig.id}/calendar.ics"
    expect(link[:download]).not_to be_nil
    expect(link['aria-label']).to eq 'Add Late Show to your calendar'
  end

  it 'copies the gig’s link where there’s no share sheet' do
    page.driver.browser.execute_cdp('Browser.grantPermissions', permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
    page.execute_script('delete Navigator.prototype.share')

    find("[data-gig-id='#{gig.id}'] [data-role='share-gig']").click

    expect(page).to have_selector("[data-gig-id='#{gig.id}'] [data-role='share-gig'][aria-label='Link copied']")
    copied = page.evaluate_async_script('navigator.clipboard.readText().then(arguments[0])')
    expect(copied).to eq "#{page.server_url}/?venue=#{venue.id}&gig=#{gig.id}"
    expect(page).to have_selector("[data-gig-id='#{gig.id}'] [data-role='share-gig'][aria-label='Share Late Show']", wait: 4)
  end
end
