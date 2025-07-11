class TicketmasterCleanupJob < ApplicationJob
  queue_as :low

  def perform
    cleanup_stats = {
      start_time: Time.current,
      old_events_removed: 0,
      cancelled_events_removed: 0
    }

    begin
      # Remove events that have ended more than 30 days ago
      cutoff_date = 30.days.ago
      old_events = Gig.where("end_time < ?", cutoff_date)
      cleanup_stats[:old_events_removed] = old_events.count
      old_events.destroy_all

      # Remove cancelled events that were cancelled more than 7 days ago
      cancelled_cutoff = 7.days.ago
      cancelled_events = Gig.where(status: "cancelled")
                           .where("updated_at < ?", cancelled_cutoff)
      cleanup_stats[:cancelled_events_removed] = cancelled_events.count
      cancelled_events.destroy_all

      cleanup_stats[:end_time] = Time.current
      cleanup_stats[:success] = true
    rescue StandardError => e
      cleanup_stats[:end_time] = Time.current
      cleanup_stats[:success] = false
      cleanup_stats[:error] = {
        class: e.class.name,
        message: e.message
      }

      # Notify about cleanup failure
      ImportMailer.cleanup_error_notification(
        error: cleanup_stats[:error],
        stats: cleanup_stats
      ).deliver_later
    ensure
      # Log cleanup results
      duration = ((cleanup_stats[:end_time] - cleanup_stats[:start_time]) / 60.0).round(2)
      Rails.logger.info <<~MSG
        Ticketmaster cleanup completed in #{duration} minutes
        Old events removed: #{cleanup_stats[:old_events_removed]}
        Cancelled events removed: #{cleanup_stats[:cancelled_events_removed]}
        Status: #{cleanup_stats[:success] ? 'Success' : 'Failed'}
      MSG
    end
  end
end
