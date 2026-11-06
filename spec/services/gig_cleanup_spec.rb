require 'rails_helper'

RSpec.describe GigCleanup do
  let!(:upcoming)        { create :gig }
  let!(:long_over)       { create :gig, start_time: 40.days.ago, end_time: 40.days.ago + 2.hours }
  let!(:recently_over)   { create :gig, start_time: 3.days.ago, end_time: 3.days.ago + 2.hours }
  let!(:stale_cancelled) { create :gig, status: 'cancelled', updated_at: 8.days.ago }
  let!(:fresh_cancelled) { create :gig, status: 'cancelled' }
  let!(:not_a_show)      { create :gig, name: 'Loft or TriStar Club Premium Seating - December 12, 2026' }

  subject!(:stats) { described_class.call }

  it 'removes gigs that ended over a month ago, week-old cancellations, and listings that aren’t shows' do
    expect(Gig.all).to contain_exactly(upcoming, recently_over, fresh_cancelled)
  end

  it { expect(stats).to eq(old_gigs_removed: 1, cancelled_gigs_removed: 1, not_shows_removed: 1) }
end
