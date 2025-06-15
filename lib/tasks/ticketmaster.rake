namespace :ticketmaster do
  desc 'Test Ticketmaster API connection'
  task test_connection: :environment do
    puts 'Testing Ticketmaster API connection...'
    client = Api::TicketmasterClient.new
    
    if client.test_connection
      puts 'Success! API connection is working.'
    else
      puts 'Failed to connect to Ticketmaster API. Please check your API key.'
    end
  end

  desc 'Test Ticketmaster API integration with a single import'
  task test_import: :environment do
    begin
      puts 'Starting test import from Ticketmaster...'
      
      # Enable debug logging
      Rails.logger = Logger.new(STDOUT)
      Rails.logger.level = :debug
      
      importer = Api::TicketmasterImporter.new
      stats = importer.import_events
      
      puts "Successfully processed #{stats[:successful]} events"
      
      if stats[:successful] > 0
        # Show a sample of what was imported
        puts "\nRecent gigs imported:"
        Gig.order(created_at: :desc).limit(3).each do |gig|
          puts "\nGig: #{gig.name}"
          puts "Venue: #{gig.venue.name} (#{gig.venue.city})"
          puts "Acts: #{gig.acts.pluck(:name).join(', ')}"
          puts "Date: #{gig.start_time.strftime('%B %d, %Y at %I:%M %p')}"
          puts "Status: #{gig.status}"
        end
      end
    rescue Api::ApiError => e
      puts "Error: #{e.message}"
    end
  end
end
