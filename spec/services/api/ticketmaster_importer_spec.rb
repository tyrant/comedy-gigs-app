require 'rails_helper'

RSpec.describe Api::TicketmasterImporter do
  let(:client) { instance_double(Api::TicketmasterClient) }
  let(:notification_service) { instance_double(NotificationService) }
  let(:metrics) { instance_double(Metrics::ImportMetrics) }
  let(:importer) { described_class.new }

  before do
    allow(Api::TicketmasterClient).to receive(:new).and_return(client)
    allow(NotificationService).to receive(:new).and_return(notification_service)
    allow(Metrics::ImportMetrics).to receive(:new).and_return(metrics)
  end

  describe '#import_events' do
    let(:event_data) do
      {
        'name' => 'Test Comedy Show',
        'dates' => {
          'start' => { 'dateTime' => '2025-06-14T20:00:00Z' }
        },
        '_embedded' => {
          'venues' => [{
            'name' => 'Test Venue',
            'city' => { 'name' => 'Auckland' },
            'country' => { 'countryCode' => 'NZ' }
          }],
          'attractions' => [{
            'name' => 'Test Comedian',
            'classifications' => [{ 'segment' => { 'name' => 'Comedy' } }]
          }]
        }
      }
    end

    let(:api_response) do
      {
        '_embedded' => { 'events' => [event_data] },
        'page' => { 'totalPages' => 1 }
      }
    end

    context 'when import is successful' do
      before do
        allow(client).to receive(:fetch_comedy_events)
          .and_return(api_response)
        allow(metrics).to receive(:record_import)
        allow(notification_service).to receive(:notify_import_success)
      end

      it 'processes events and records metrics' do
        stats = importer.import_events

        expect(stats[:total_processed]).to eq(1)
        expect(stats[:successful]).to eq(0)
        expect(stats[:failed]).to eq(0)
        expect(stats[:skipped]).to eq(1)
        expect(metrics).to have_received(:record_import).with(
          hash_including(
            total_processed: 1,
            successful: 0,
            failed: 0,
            skipped: 1,
            rate_limited: 0
          )
        )
      end

      it 'sends success notification' do
        expect(notification_service).to receive(:notify_import_success)
          .with(hash_including(
            total_processed: 1,
            successful: 0,
            failed: 0,
            skipped: 1,
            rate_limited: 0
          ))

        importer.import_events
      end
    end

    context 'when import encounters errors' do
      before do
        allow(client).to receive(:fetch_comedy_events).and_raise(StandardError.new('API Error'))
        allow(notification_service).to receive(:notify_import_error)
        allow(metrics).to receive(:record_import)
      end

      it 'handles errors and sends notifications' do
        stats = importer.import_events

        expect(notification_service).to have_received(:notify_import_error).with(
          hash_including(
            error: instance_of(StandardError),
            stats: hash_including(
              total_processed: 0,
              successful: 0,
              failed: 0,
              skipped: 0,
              rate_limited: 0,
              start_time: kind_of(Time),
              end_time: kind_of(Time),
              event: nil
            )
          )
        )

        expect(metrics).to have_received(:record_import).with(
          hash_including(
            total_processed: 0,
            successful: 0,
            failed: 0,
            skipped: 0,
            rate_limited: 0,
            start_time: kind_of(Time),
            end_time: kind_of(Time)
          )
        )

        expect(stats[:failed]).to eq(0)
        expect(stats[:total_processed]).to eq(0)
      end
    end

    context 'when rate limit is hit' do
      before do
        error = Api::RateLimitError.new('Rate limit exceeded')
        allow(client).to receive(:fetch_comedy_events).and_raise(error)
        allow(notification_service).to receive(:notify_import_error)
        allow(notification_service).to receive(:notify_import_success)
        allow(metrics).to receive(:record_import)
        allow_any_instance_of(Kernel).to receive(:sleep)
      end

      it 'handles rate limit errors and records stats' do
        stats = importer.import_events

        expect(stats[:rate_limited]).to eq(1)
        expect(stats[:successful]).to eq(0)
        expect(stats[:total_processed]).to eq(0)
        expect(notification_service).to have_received(:notify_import_error).with(
          hash_including(
            error: instance_of(Api::RateLimitError),
            stats: hash_including(
              total_processed: 0,
              successful: 0,
              failed: 0,
              skipped: 0,
              rate_limited: 1,
              start_time: kind_of(Time),
              end_time: kind_of(Time),
              event: nil
            )
          )
        )
        expect(metrics).to have_received(:record_import).twice.with(
          hash_including(
            total_processed: 0,
            successful: 0,
            failed: 0,
            skipped: 0,
            rate_limited: 1,
            start_time: kind_of(Time),
            end_time: kind_of(Time)
          )
        )
      end
    end

    context 'when event is invalid' do
      let(:api_response_with_invalid_event) do
        {
          '_embedded' => {
            'events' => [
              { 'name' => 'Invalid Event' } # Missing required fields
            ]
          },
          'page' => {
            'totalPages' => 1
          }
        }
      end

      before do
        allow(client).to receive(:fetch_comedy_events).and_return(api_response_with_invalid_event)
        allow(notification_service).to receive(:notify_import_error)
        allow(notification_service).to receive(:notify_import_success)
        allow(metrics).to receive(:record_import)
      end

      it 'skips invalid events' do
        stats = importer.import_events

        expect(stats[:skipped]).to eq(1)
        expect(stats[:successful]).to eq(0)
        expect(stats[:total_processed]).to eq(1)
        expect(metrics).to have_received(:record_import).with(
          hash_including(
            total_processed: 1,
            successful: 0,
            failed: 0,
            skipped: 1,
            rate_limited: 0,
            start_time: kind_of(Time),
            end_time: kind_of(Time)
          )
        )
      end
    end
  end
end
