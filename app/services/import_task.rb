# Runs one source's import for a rake task, logs the outcome and reports it to
# the monitor. A fatal error, or a run that found nothing at all, reports as
# crashed; individual events that failed are counted and sampled.
class ImportTask
  def self.call(source:, script:)
    Rails.logger.info "Starting #{source} import..."
    started = Time.current
    stats = yield

    Rails.logger.info "#{source} import finished in #{((Time.current - started) / 60).round(2)} minutes: " \
      "#{stats.slice(:total_processed, :successful, :failed, :skipped, :rate_limited).map { |k, v| "#{k} #{v}" }.join(', ')}"

    errors = []
    errors << "#{stats[:error][:class]}: #{stats[:error][:message]}" if stats[:error]
    errors << "#{source} returned no events" if stats[:total_processed].zero?

    MonitorClient.report_run(
      script:,
      status: errors.any? ? "crashed" : "success",
      processed: stats[:successful],
      failed: stats[:failed],
      skipped: stats[:skipped],
      errors: errors + stats[:error_samples]
    )
    stats
  rescue StandardError => e
    Rails.logger.error "#{source} import failed: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace&.first(10)&.join("\n")
    MonitorClient.report_run(script:, status: "crashed", errors: [ "#{e.class}: #{e.message}", *(e.backtrace&.first(10) || []) ])
    nil
  end
end
