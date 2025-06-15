class NotificationService
  def initialize(notifiers = [])
    @notifiers = Array(notifiers)
    setup_notifiers if @notifiers.empty?
  end

  def notify_import_error(error:, stats:)
    @notifiers.each do |notifier|
      if notifier == ImportMailer
        notifier.error_notification(error: error, stats: stats).deliver_later
      elsif notifier.respond_to?(:notify_import_error)
        notifier.notify_import_error(error: error, stats: stats)
      end
    end
  end

  def notify_import_success(stats)
    @notifiers.each do |notifier|
      if notifier == ImportMailer
        notifier.success_notification(stats).deliver_later
      elsif notifier.respond_to?(:notify_import_success)
        notifier.notify_import_success(stats)
      end
    end
  end

  def notify_cleanup_complete(stats)
    @notifiers.each do |notifier|
      next if notifier == ImportMailer # Skip email for cleanup notifications
      if notifier.respond_to?(:notify_cleanup_complete)
        notifier.notify_cleanup_complete(stats)
      end
    end
  end

  private

  def setup_notifiers
    # Add email notifier
    @notifiers << ImportMailer

    # Add Slack notifier if configured
    if Rails.application.credentials.dig(:slack, :webhook_url)
      @notifiers << Notifiers::SlackNotifier.new
    end
  end
end
