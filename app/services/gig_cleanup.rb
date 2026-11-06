# Prunes gigs nobody will look for again: ones that ended a month ago,
# cancellations that have been sitting for a week, and listings that aren't
# shows (Gig::NOT_A_SHOW), which an import may have brought in before it knew
# to skip them. Runs after the nightly import.
class GigCleanup
  ENDED_BEFORE     = 30.days
  CANCELLED_BEFORE = 7.days

  def self.call
    new.call
  end

  def call
    old = Gig.where(end_time: ...ENDED_BEFORE.ago)
    cancelled = Gig.where(status: "cancelled", updated_at: ...CANCELLED_BEFORE.ago)
    not_shows = Gig.where(id: Gig.pluck(:id, :name).filter_map { |id, name| id if Gig.not_a_show?(name) })

    stats = { old_gigs_removed: old.destroy_all.size, cancelled_gigs_removed: cancelled.destroy_all.size,
              not_shows_removed: not_shows.destroy_all.size }
    Rails.logger.info "Gig cleanup: removed #{stats[:old_gigs_removed]} old and #{stats[:cancelled_gigs_removed]} cancelled gigs, " \
                      "and #{stats[:not_shows_removed]} listings that weren't shows"
    stats
  end
end
