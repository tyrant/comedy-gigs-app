# Prunes gigs nobody will look for again: ones that ended a month ago, and
# cancellations that have been sitting for a week. Runs after the nightly import.
class GigCleanup
  ENDED_BEFORE     = 30.days
  CANCELLED_BEFORE = 7.days

  def self.call
    new.call
  end

  def call
    old = Gig.where(end_time: ...ENDED_BEFORE.ago)
    cancelled = Gig.where(status: "cancelled", updated_at: ...CANCELLED_BEFORE.ago)

    stats = { old_gigs_removed: old.destroy_all.size, cancelled_gigs_removed: cancelled.destroy_all.size }
    Rails.logger.info "Gig cleanup: removed #{stats[:old_gigs_removed]} old and #{stats[:cancelled_gigs_removed]} cancelled gigs"
    stats
  end
end
