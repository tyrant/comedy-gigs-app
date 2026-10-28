# Folds one record into another that describes the same venue, act or gig:
# the duplicate's gigs, lineup and source links move across, the kept record
# takes any details it was missing, and the duplicate is deleted.
class RecordMerger
  # Not copied across: identity, bookkeeping, and values derived from others
  SKIPPED = %w[id created_at updated_at match_key local_date].freeze

  def self.call(keep, duplicate) = new(keep, duplicate).call

  def initialize(keep, duplicate)
    raise ArgumentError, "can't merge a #{duplicate.class} into a #{keep.class}" unless keep.class == duplicate.class
    raise ArgumentError, "can't merge a record into itself" if keep == duplicate

    @keep, @duplicate = keep, duplicate
  end

  def call
    ActiveRecord::Base.transaction do
      move_dependents
      @duplicate.source_links.update_all(linkable_id: @keep.id, updated_at: Time.current)
      fill_blanks
      @duplicate.reload.destroy!
    end
    @keep
  end

  private

  def move_dependents
    case @keep
    when Venue
      @duplicate.gigs.each { |gig| gig.update!(venue: @keep) } # each, so local dates follow the new venue
    when Act
      gig_ids = @duplicate.gig_ids - @keep.gig_ids
      @keep.gigs << Gig.where(id: gig_ids)
      @duplicate.gigs.clear
    when Gig
      @keep.acts << (@duplicate.acts - @keep.acts)
    end
  end

  def fill_blanks
    blanks = @duplicate.attributes.except(*SKIPPED).select { |name, value| value.present? && @keep[name].blank? }
    @keep.update!(blanks) if blanks.any?
  end
end
