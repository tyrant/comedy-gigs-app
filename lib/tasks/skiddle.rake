namespace :skiddle do
  desc "Check the Skiddle API key works"
  task test_connection: :environment do
    if Api::SkiddleClient.new.test_connection
      puts "Connected to Skiddle."
    else
      abort "Couldn't connect to Skiddle; check the API key."
    end
  end

  desc "Show how the first page of Skiddle comedy would import, without saving anything"
  task preview: :environment do
    response = Api::SkiddleClient.new.fetch_comedy_events(limit: 20)
    puts "#{response['totalcount']} upcoming comedy events on Skiddle"

    response["results"].each do |event|
      result = Api::SkiddleTransformer.transform_event(event)
      if result
        artists = result[:acts].map { |act| act[:name] }
        puts "#{result[:gig][:name]} @ #{result[:venue][:name]}, #{result[:venue][:city]}: #{result[:gig][:start_time]}" \
          "#{" with #{artists.join(', ')}" if artists.any?}#{' (cancelled)' if result[:gig][:status] == 'cancelled'}"
      else
        puts "#{event['eventname']}: skipped (no location, or already over)"
      end
    end
  end

  desc "Import upcoming UK comedy from Skiddle and report to the monitor"
  task daily_import: :environment do
    ImportTask.call(source: "Skiddle", script: "skiddle_import") { Api::SkiddleImporter.new.import_events }
  end
end
