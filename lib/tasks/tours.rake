namespace :tours do
  desc "Work out acts' tours from their gigs' names"
  task assemble: :environment do
    stats = TourFinder.call
    MonitorClient.report_run(script: "tours", status: "success", processed: stats[:tours])
    puts stats.inspect
  rescue StandardError => e
    Rails.logger.error "Tour assembly failed: #{e.class}: #{e.message}"
    MonitorClient.report_run(script: "tours", status: "crashed", errors: [ "#{e.class}: #{e.message}" ])
  end
end
