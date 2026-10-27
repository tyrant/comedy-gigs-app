require 'rails_helper'

RSpec.describe GigCleanup do
  let!(:upcoming)        { create :gig }
  let!(:long_over)       { create :gig, start_time: 40.days.ago, end_time: 40.days.ago + 2.hours }
  let!(:recently_over)   { create :gig, start_time: 3.days.ago, end_time: 3.days.ago + 2.hours }
  let!(:stale_cancelled) { create :gig, status: 'cancelled', updated_at: 8.days.ago }
  let!(:fresh_cancelled) { create :gig, status: 'cancelled' }

  subject!(:stats) { described_class.call }

  it 'removes gigs that ended over a month ago, and week-old cancellations' do
    expect(Gig.all).to contain_exactly(upcoming, recently_over, fresh_cancelled)
  end

  it { expect(stats).to eq(old_gigs_removed: 1, cancelled_gigs_removed: 1) }
end
