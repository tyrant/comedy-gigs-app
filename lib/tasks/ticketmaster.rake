namespace :ticketmaster do
  desc "Test Ticketmaster API connection"
  task test_connection: :environment do
    puts "Testing Ticketmaster API connection..."
    client = Api::TicketmasterClient.new

    if client.test_connection
      puts "Success! API connection is working."
    else
      puts "Failed to connect to Ticketmaster API. Please check your API key."
    end
  end

  desc "Debug image data from Ticketmaster API"
  task debug_images: :environment do
    puts "Starting Ticketmaster image data debugging..."
    client = Api::TicketmasterClient.new

    # Get a small sample of events
    response = client.fetch_comedy_events(size: 3, page: 0)

    if response && response["_embedded"] && response["_embedded"]["events"]
      events = response["_embedded"]["events"]
      puts "Found #{events.size} events for debugging"

      events.each do |event|
        puts "\n=== EVENT: #{event['name']} ==="

        # Process the event to see logs
        transformed = Api::TicketmasterTransformer.transform_event(event)

        # Print summary after transformation
        if transformed[:venue] && transformed[:venue][:images].present?
          puts "Venue images found: #{transformed[:venue][:images].keys.join(', ')}"
        else
          puts "No venue images found"
        end

        if transformed[:acts].present?
          transformed[:acts].each do |act|
            if act[:images].present?
              puts "Act '#{act[:name]}' images found: #{act[:images].keys.join(', ')}"
            else
              puts "No images found for act '#{act[:name]}'"
            end
          end
        else
          puts "No acts found in event"
        end
      end
    else
      puts "No events found or API error"
    end
  end

  desc "Test Ticketmaster API integration with a single import"
  task test_import: :environment do
    begin
      Rails.logger.info "Starting test import from Ticketmaster..."

      start_time = Time.current
      importer = Api::TicketmasterImporter.new
      stats = importer.import_events
      duration = ((Time.current - start_time) / 60).round(2)

      Rails.logger.info "Import completed in #{duration} minutes"
      Rails.logger.info "Total processed: #{stats[:total_processed]}"
      Rails.logger.info "Successful: #{stats[:successful]}"
      Rails.logger.info "Failed: #{stats[:failed]}"
      Rails.logger.info "Skipped: #{stats[:skipped]}"
      Rails.logger.info "Rate limited: #{stats[:rate_limited]}"

      if stats[:successful] > 0
        # Log a sample of what was imported
        recent_gigs = Gig.order(created_at: :desc).limit(3)
        recent_gigs.each do |gig|
          Rails.logger.info "Imported: #{gig.name} at #{gig.venue.name} on #{gig.start_time.strftime('%Y-%m-%d')}"
        end
      end

      Rails.logger.info "Ticketmaster import completed successfully"
    rescue StandardError => e
      Rails.logger.error "Ticketmaster import failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise # Re-raise to ensure the task fails properly
    end
  end

  desc "Production Ticketmaster scheduled import"
  task daily_import: :environment do
    begin
      Rails.logger.info "Starting daily Ticketmaster import..."

      start_time = Time.current
      importer = Api::TicketmasterImporter.new
      stats = importer.import_events
      duration = ((Time.current - start_time) / 60).round(2)

      Rails.logger.info "Daily import completed in #{duration} minutes"
      Rails.logger.info "Total processed: #{stats[:total_processed]}"
      Rails.logger.info "Successful: #{stats[:successful]}"
      Rails.logger.info "Failed: #{stats[:failed]}"
      Rails.logger.info "Skipped: #{stats[:skipped]}"
      Rails.logger.info "Rate limited: #{stats[:rate_limited]}"

      # Record metrics
      metrics = Metrics::ImportMetrics.new
      metrics.record_import(stats)

      Rails.logger.info "Daily Ticketmaster import completed successfully"
    rescue StandardError => e
      Rails.logger.error "Daily Ticketmaster import failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Send error notification
      NotificationService.new.notify_import_error(
        error: {
          message: e.message,
          class: e.class.to_s,
          backtrace: e.backtrace&.first(10) || []
        },
        stats: { error_time: Time.current }
      )
    end
  end
end
