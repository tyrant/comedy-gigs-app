class ImportMailer < ApplicationMailer
  default from: "noreply@comedygigs.example.com"

  def error_notification(error:, stats:)
    @error = error
    @stats = stats

    mail(
      to: admin_email,
      subject: "[ComedyGigs] Import Error: #{@error[:class]}"
    )
  end

  def success_notification(stats)
    @stats = stats

    mail(
      to: admin_email,
      subject: "[ComedyGigs] Import Summary: #{@stats[:total_processed]} events processed"
    )
  end

  def cleanup_error_notification(details)
    @error = details[:error]
    @stats = details[:stats]

    mail(
      to: admin_email,
      subject: "[ComedyGigs] Cleanup Error: #{@error[:class]}"
    )
  end

  private

  def admin_email
    Rails.application.credentials.admin_email
  end
end
