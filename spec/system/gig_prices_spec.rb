require 'rails_helper'

RSpec.describe 'Gig prices', type: :system, js: true do
  let!(:venue) { create :venue, name: 'The Classic', city: 'Auckland', latitude: -36.85, longitude: 174.76, timezone: 'Pacific/Auckland' }
  let!(:act) { create :act, name: 'Rose Matafeo' }
  let!(:tiered) do
    create :gig, name: 'Late Show', venue:, acts: [ act ], start_time: 1.week.from_now, end_time: nil,
                 price_min: 28, price_max: 160, currency: 'NZD', ticket_tiers: [
                   { 'name' => 'General Admission', 'price' => 28.0, 'sold_out' => false, 'few_left' => true },
                   { 'name' => 'Table for Four', 'price' => 160.0, 'sold_out' => true, 'few_left' => false }
                 ]
  end
  let!(:free) { create :gig, name: 'Open Mic', venue:, start_time: 2.weeks.from_now, end_time: nil, price_min: 0, price_max: 0, currency: 'NZD' }
  let!(:unpriced) { create :gig, name: 'Mystery Show', venue:, start_time: 3.weeks.from_now, end_time: nil }

  def row(gig) = find("#venue-details [data-gig-id='#{gig.id}']")

  before do
    page.driver.browser.execute_cdp('Emulation.setLocaleOverride', locale: 'en-NZ')
    visit root_path(venue: venue.id)
    expect(page).to have_selector('#venue-details h2', text: 'The Classic')
  end

  it 'shows each gig’s price range, a few-left warning, and its ticket types on request' do
    within(row(tiered)) do
      expect(find('[data-role="gig-price"]')).to have_text('$28–$160')
      expect(page).to have_text('Few left')
      expect(page).to have_no_text('Table for Four')

      find('[data-role="ticket-tiers"] summary', text: '2 ticket types').click
      expect(page).to have_text('General Admission')
      expect(page).to have_text(/Table for Four\s*\$160\s*Sold out/)
    end

    expect(row(free).find('[data-role="gig-price"]')).to have_text('Free')
    expect(row(unpriced)).to have_no_selector('[data-role="gig-price"]')
  end

  it 'shows them in the act’s view too' do
    within('#venue-details') { click_link 'Rose Matafeo' }
    expect(find("#act-details [data-gig-id='#{tiered.id}'] [data-role='gig-price']")).to have_text('$28–$160')
  end
end
