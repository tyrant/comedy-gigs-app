require 'rails_helper'

RSpec.describe Notifiers::SlackNotifier do
  let(:webhook_url) { 'https://hooks.slack.com/services/test' }
  let(:channel) { '#test-channel' }
  let(:notifier_double) { instance_double(Slack::Notifier) }

  before do
    allow(Rails.application.credentials).to receive(:slack)
      .and_return({ webhook_url: webhook_url, channel: channel })
    allow(Slack::Notifier).to receive(:new).with(webhook_url).and_return(notifier_double)
  end

  describe '#notify_import_error' do
    let(:error) do
      {
        class: 'StandardError',
        message: 'Test error',
        backtrace: ['line 1', 'line 2']
      }
    end
    let(:stats) do
      {
        total_processed: 10,
        successful: 8,
        failed: 1,
        skipped: 1,
        rate_limited: 0,
        start_time: Time.current - 5.minutes,
        end_time: Time.current
      }
    end

    describe 'sending error notification' do
      before do
        allow(notifier_double).to receive(:ping)
        subject.notify_import_error(error: error, stats: stats)
      end

      it 'sends message with error details' do
        expect(notifier_double).to have_received(:ping)
          .with(
            include('*Import Error*', 'StandardError - Test error'),
            hash_including(
              channel: channel,
              username: 'Comedy Gigs Bot',
              icon_emoji: ':x:'
            )
          )
      end
    end

    describe 'handling Slack API errors' do
      before do
        allow(notifier_double).to receive(:ping).and_raise('Slack API error')
        allow(Rails.logger).to receive(:error)
        subject.notify_import_error(error: error, stats: stats)
      end

      it 'logs error message' do
        expect(Rails.logger).to have_received(:error)
          .with(/Failed to send Slack notification/)
      end
    end
  end

  describe '#notify_import_success' do
    let(:stats) do
      {
        total_processed: 20,
        successful: 18,
        failed: 0,
        skipped: 2,
        rate_limited: 0,
        start_time: Time.current - 10.minutes,
        end_time: Time.current
      }
    end

    describe 'sending success notification' do
      before do
        allow(notifier_double).to receive(:ping)
        subject.notify_import_success(stats)
      end

      it 'sends message with success details' do
        expect(notifier_double).to have_received(:ping)
          .with(
            include('*Import Completed Successfully*', 'Total processed: 20'),
            hash_including(
              channel: channel,
              username: 'Comedy Gigs Bot',
              icon_emoji: ':white_check_mark:'
            )
          )
      end
    end
  end

  describe '#notify_cleanup_complete' do
    let(:stats) do
      {
        old_events_removed: 5,
        cancelled_events_removed: 3,
        start_time: Time.current - 2.minutes,
        end_time: Time.current
      }
    end

    describe 'sending cleanup notification' do
      before do
        allow(notifier_double).to receive(:ping)
        subject.notify_cleanup_complete(stats)
      end

      it 'sends message with cleanup details' do
        expect(notifier_double).to have_received(:ping)
          .with(
            include('*Cleanup Completed*', 'Old events removed: 5'),
            hash_including(
              channel: channel,
              username: 'Comedy Gigs Bot',
              icon_emoji: ':broom:'
            )
          )
      end
    end
  end
end
