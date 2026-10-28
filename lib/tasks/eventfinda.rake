namespace :eventfinda do
  desc "Check the Eventfinda API credentials work"
  task test_connection: :environment do
    if Api::EventfindaClient.new.test_connection
      puts "Connected to Eventfinda."
    else
      abort "Couldn't connect to Eventfinda; check the API username and password."
    end
  end

  desc "Show how the first page of Eventfinda comedy would import, without saving anything"
  task preview: :environment do
    response = Api::EventfindaClient.new.fetch_comedy_events
    puts "#{response.dig('@attributes', 'count')} upcoming comedy events on Eventfinda"

    response["events"].each do |event|
      result = Api::EventfindaTransformer.transform_event(event)
      if result
        puts "#{event['name']} @ #{result[:venue][:name]}, #{result[:venue][:city]}: #{result[:gigs].size} gig(s), " \
          "first #{result[:gigs].first[:start_time]}"
      else
        puts "#{event['name']}: skipped (no location, or no upcoming sessions)"
      end
    end
  end

  desc "Import upcoming comedy from Eventfinda and report to the monitor"
  task daily_import: :environment do
    ImportTask.call(source: "Eventfinda", script: "eventfinda_import") { Api::EventfindaImporter.new.import_events }
  end
end

namespace :acts do
  desc "Find Wikipedia bios for comedians with gigs coming up (a batch a night) and report to the monitor"
  task bios: :environment do
    ImportTask.call(source: "Wikipedia bios", script: "act_bios", allow_empty: true) { ActBios.call }
  end
end

namespace :import do
  desc "Run every source's import, find bios, then prune old gigs"
  task all: %w[ticketmaster:daily_import eventfinda:daily_import acts:bios] do
    stats = GigCleanup.call
    MonitorClient.report_run(script: "gig_cleanup", status: "success", processed: stats.values.sum)
  rescue StandardError => e
    Rails.logger.error "Gig cleanup failed: #{e.class}: #{e.message}"
    MonitorClient.report_run(script: "gig_cleanup", status: "crashed", errors: [ "#{e.class}: #{e.message}" ])
  end
end
