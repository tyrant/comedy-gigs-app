require "slack-notifier"

module Notifiers
  class SlackNotifier
    def initialize
      @webhook_url = Rails.application.credentials.slack[:webhook_url]
      @notifier = Slack::Notifier.new(@webhook_url)
      @channel = Rails.application.credentials.slack[:channel] || "#comedy-gigs-alerts"
    end

    def notify_import_error(error:, stats:)
      message = build_error_message(error, stats)
      send_notification(message, ":x:")
    end

    def notify_import_success(stats)
      message = build_success_message(stats)
      send_notification(message, ":white_check_mark:")
    end

    def notify_cleanup_complete(stats)
      message = build_cleanup_message(stats)
      send_notification(message, ":broom:")
    end

    private

    def send_notification(message, emoji)
      @notifier.ping(
        message,
        channel: @channel,
        username: "Comedy Gigs Bot",
        icon_emoji: emoji
      )
    rescue StandardError => e
      Rails.logger.error "Failed to send Slack notification: #{e.message}"
    end

    def build_error_message(error, stats)
      <<~MSG
        *Import Error*
        Error: #{error[:class]} - #{error[:message]}
        #{format_stats(stats)}
      MSG
    end

    def build_success_message(stats)
      <<~MSG
        *Import Completed Successfully*
        #{format_stats(stats)}
      MSG
    end

    def build_cleanup_message(stats)
      <<~MSG
        *Cleanup Completed*
        • Old events removed: #{stats[:old_events_removed]}
        • Cancelled events removed: #{stats[:cancelled_events_removed]}
        • Duration: #{((stats[:end_time] - stats[:start_time]) / 60.0).round(2)} minutes
      MSG
    end

    def format_stats(stats)
      return "" unless stats

      <<~STATS
        • Total processed: #{stats[:total_processed]}
        • Successful: #{stats[:successful]}
        • Failed: #{stats[:failed]}
        • Skipped: #{stats[:skipped]}
        • Rate limited: #{stats[:rate_limited]}
        • Duration: #{((stats[:end_time] - stats[:start_time]) / 60.0).round(2)} minutes
      STATS
    end
  end
end
