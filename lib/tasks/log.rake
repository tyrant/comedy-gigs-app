namespace :log do
  desc 'Log an info message to the Rails log'
  task :info, [:message] => :environment do |_, args|
    message = args[:message] || 'No message provided'
    Rails.logger.info(message)
    puts message
  end

  desc 'Log an error message to the Rails log'
  task :error, [:message] => :environment do |_, args|
    message = args[:message] || 'No message provided'
    Rails.logger.error(message)
    puts "ERROR: #{message}"
  end
end
