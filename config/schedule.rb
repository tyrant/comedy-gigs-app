# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# Set environment to run in production mode
set :environment, "production"

# Set output path for cron logs
set :output, { error: "/home/noob/comedy-gigs-app/shared/log/cron_error.log", standard: "/home/noob/comedy-gigs-app/shared/log/cron.log" }

# Set job template to include the correct environment and path
set :job_template, '/bin/bash -l -c ":job"'

# Every source's import (Ticketmaster, then Eventfinda), then a prune of old gigs
every 1.day, at: "2:00 am" do
  rake "import:all"
end

# Uncomment and modify for additional scheduled tasks
# every :sunday, at: '12:00 pm' do
#   rake 'some:weekly:task'
# end
