require "sidekiq"
require "sidekiq-scheduler"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }

  # Load the schedule
  config.on(:startup) do
    schedule_file = Rails.root.join("config", "sidekiq.yml")
    if File.exist?(schedule_file)
      yaml = YAML.load_file(schedule_file) || {}
      Sidekiq.schedule = yaml.fetch(:scheduler, {}).fetch(:schedule, {})
      SidekiqScheduler::Scheduler.instance.reload_schedule!
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }
end
