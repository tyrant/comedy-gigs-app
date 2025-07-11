class TicketmasterImportJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info "Starting scheduled Ticketmaster import at #{Time.current}"

    importer = Api::TicketmasterImporter.new
    stats = importer.import_events

    if stats[:failed] > 0
      Rails.logger.warn "Import completed with #{stats[:failed]} failures"
    else
      Rails.logger.info "Import completed successfully"
    end

    # Schedule next import if not already scheduled
    ensure_next_import_scheduled
  rescue StandardError => e
    Rails.logger.error "Import failed: #{e.message}"
    notify_error(e)
    raise # Re-raise to trigger retry
  end

  private

  def ensure_next_import_scheduled
    next_import = Sidekiq::ScheduledSet.new.find_job("ticketmaster_import")
    unless next_import
      self.class.set(wait: 4.hours).perform_later
      Rails.logger.info "Scheduled next import for #{4.hours.from_now}"
    end
  end

  def notify_error(error)
    ImportMailer.import_error_notification(
      error: {
        class: error.class.name,
        message: error.message,
        backtrace: error.backtrace || []
      },
      import_stats: {
        error_time: Time.current
      }
    ).deliver_later
  end
end
