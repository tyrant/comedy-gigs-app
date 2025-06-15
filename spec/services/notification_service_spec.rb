require 'rails_helper'

RSpec.describe NotificationService do
  let(:slack_notifier) { instance_double(Notifiers::SlackNotifier) }
  let(:service) { described_class.new }
  let(:stats) do
    {
      total_processed: 15,
      successful: 12,
      failed: 2,
      skipped: 1,
      rate_limited: 0,
      start_time: Time.current - 5.minutes,
      end_time: Time.current
    }
  end

  before do
    # Mock Slack credentials
    allow(Rails.application.credentials).to receive(:dig)
      .with(:slack, :webhook_url)
      .and_return('https://hooks.slack.com/test')

    # Mock Slack notifier instantiation
    allow(Notifiers::SlackNotifier).to receive(:new).and_return(slack_notifier)
  end

  describe '#notify_import_error' do
    let(:error) do
      {
        class: 'StandardError',
        message: 'Test error',
        backtrace: ['line 1', 'line 2']
      }
    end

    it 'sends notifications to all configured notifiers' do
      # Email notification expectations
      mailer = double('mailer')
      expect(ImportMailer).to receive(:error_notification)
        .with(hash_including(error: error))
        .and_return(mailer)
      expect(mailer).to receive(:deliver_later)

      # Slack notification expectations
      expect(slack_notifier).to receive(:notify_import_error)
        .with(error: error, stats: stats)

      service.notify_import_error(error: error, stats: stats)
    end

    context 'when Slack is not configured' do
      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:slack, :webhook_url)
          .and_return(nil)
      end

      it 'only sends email notifications' do
        mailer = double('mailer')
        expect(ImportMailer).to receive(:error_notification)
          .with(hash_including(error: error, stats: stats))
          .and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        expect(slack_notifier).not_to receive(:notify_import_error)

        service.notify_import_error(error: error, stats: stats)
      end
    end
  end

  describe '#notify_import_success' do
    it 'sends notifications to all configured notifiers' do
      # Email notification expectations
      mailer = double('mailer')
      expect(ImportMailer).to receive(:success_notification)
        .with(stats)
        .and_return(mailer)
      expect(mailer).to receive(:deliver_later)

      # Slack notification expectations
      expect(slack_notifier).to receive(:notify_import_success)
        .with(stats)

      service.notify_import_success(stats)
    end
  end

  describe '#notify_cleanup_complete' do
    let(:cleanup_stats) do
      {
        old_events_removed: 5,
        cancelled_events_removed: 3,
        start_time: Time.current - 2.minutes,
        end_time: Time.current
      }
    end

    it 'sends notifications to all configured notifiers' do
      expect(slack_notifier).to receive(:notify_cleanup_complete)
        .with(hash_including(cleanup_stats))

      service.notify_cleanup_complete(cleanup_stats)
    end
  end
end
