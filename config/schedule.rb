# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# Set environment to run in production mode
set :environment, "production"

# Set output path for cron logs
set :output, { error: "log/cron_error.log", standard: "log/cron.log" }

# Set job template to include the correct environment and path
set :job_template, '/bin/bash -l -c ":job"'

# Define the schedule for the Ticketmaster import task
every 1.day, at: "2:00 am" do
  # Run the Ticketmaster import task daily at 2 AM
  rake "ticketmaster:daily_import"
end

# Uncomment and modify for additional scheduled tasks
# every :sunday, at: '12:00 pm' do
#   rake 'some:weekly:task'
# end
