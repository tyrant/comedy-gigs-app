require 'rails_helper'

RSpec.describe 'The Tonight dates', type: :system, js: true do
  # The venue has no time zone, so its dates are UTC's; the browser's are made so too
  let!(:venue) { create :venue, name: 'The Classic', city: 'Auckland', latitude: -36.85, longitude: 174.76, timezone: nil }
  let!(:matinee) { create :gig, name: 'Matinee', venue:, start_time: 3.hours.ago, end_time: 1.hour.ago }
  let!(:late_show) { create :gig, name: 'Late Show', venue:, start_time: 1.minute.from_now, end_time: 2.hours.from_now }

  it 'shows what’s still to come today, leaving out what’s over, but not when looking back' do
    skip 'needs both gigs on the same UTC date' unless [ matinee, late_show ].map { |gig| gig.start_time.utc.to_date }.uniq.one?

    page.driver.browser.execute_cdp('Emulation.setTimezoneOverride', timezoneId: 'UTC')
    visit root_path(venue: venue.id)
    find('#date_preset').select('Tonight')

    within('#venue-details') do
      expect(page).to have_text('Late Show')
      expect(page).not_to have_text('Matinee')
    end

    visit root_path(venue: venue.id, start: 1.day.ago.utc.to_date.iso8601, end: Time.current.utc.to_date.iso8601)
    within('#venue-details') { expect(page).to have_text('Matinee') }
  end
end
