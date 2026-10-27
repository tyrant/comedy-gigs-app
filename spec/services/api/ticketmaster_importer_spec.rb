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
          'venues' => [ {
            'name' => 'Test Venue',
            'city' => { 'name' => 'Auckland' },
            'country' => { 'countryCode' => 'NZ' }
          } ],
          'attractions' => [ {
            'name' => 'Test Comedian',
            'classifications' => [ { 'segment' => { 'name' => 'Comedy' } } ]
          } ]
        }
      }
    end

    let(:api_response) do
      {
        '_embedded' => { 'events' => [ event_data ] },
        'page' => { 'totalPages' => 1 }
      }
    end

    # A single one-week window, so each stubbed response is fetched once
    subject { importer.import_events(horizon: 7.days) }

    context 'when import is successful' do
      before do
        allow(client).to receive(:fetch_comedy_events)
          .and_return(api_response)
        allow(metrics).to receive(:record_import)
        allow(notification_service).to receive(:notify_import_success)

        subject
      end

      describe 'processing events and records metrics' do
        it { expect(subject[:total_processed]).to eq 1 }
        it { expect(subject[:successful]).to eq 0 }
        it { expect(subject[:failed]).to eq 0 }
        it { expect(subject[:skipped]).to eq 1 }
        it { expect(metrics).to have_received(:record_import)
               .with hash_including(total_processed: 1,
                                    successful: 0,
                                    failed: 0,
                                    skipped: 1,
                                    rate_limited: 0) }
      end

      it 'sends success notification' do
        expect(notification_service).to have_received(:notify_import_success)
          .with hash_including(total_processed: 1,
                               successful: 0,
                               failed: 0,
                               skipped: 1,
                               rate_limited: 0,
                               source: 'ticketmaster')
      end
    end

    context 'when the API reports more pages than its deep-paging ceiling allows' do
      let(:deep_response) do
        {
          '_embedded' => { 'events' => [ event_data ] },
          'page' => { 'totalPages' => 100 }
        }
      end

      before do
        allow(client).to receive(:fetch_comedy_events).and_return(deep_response)
        allow(metrics).to receive(:record_import)
        allow(notification_service).to receive(:notify_import_success)

        subject
      end

      it 'stops at the 1000-item ceiling instead of paging into a 400' do
        expected_pages = Api::TicketmasterClient::MAX_RESULTS / Api::TicketmasterClient::PAGE_SIZE
        expect(client).to have_received(:fetch_comedy_events).exactly(expected_pages).times
      end
    end

    context 'when a window holds more events than the API will page through' do
      let(:crowded_response) { { '_embedded' => { 'events' => [ event_data ] }, 'page' => { 'totalPages' => 100, 'totalElements' => 10_000 } } }
      let(:windows) { [] }

      before do
        allow(client).to receive(:fetch_comedy_events) do |starts_after:, starts_before:, **|
          windows << [ starts_after, starts_before ]
          (starts_before - starts_after) > 2.days ? crowded_response : api_response
        end
        allow(metrics).to receive(:record_import)
        allow(notification_service).to receive(:notify_import_success)

        subject
      end

      it 'halves the window until each part fits under the ceiling' do
        imported = windows.select { |from, to| (to - from) <= 2.days }
        expect(imported.size).to eq 4
        expect(imported.first.first).to eq windows.first.first
        expect(imported.last.last).to eq windows.first.last
        imported.each_cons(2) { |(_, end1), (start2, _)| expect(start2).to eq end1 }
      end
    end

    context 'when the horizon spans several windows' do
      let(:windows) { [] }

      before do
        allow(client).to receive(:fetch_comedy_events) do |starts_after:, starts_before:, **|
          windows << [ starts_after, starts_before ]
          api_response
        end
        allow(metrics).to receive(:record_import)
        allow(notification_service).to receive(:notify_import_success)

        importer.import_events(horizon: 30.days)
      end

      it 'walks contiguous week-long windows up to the horizon' do
        expect(windows.size).to eq 5
        expect(windows.map { |from, to| to - from }).to eq [ 7.days, 7.days, 7.days, 7.days, 2.days ]
        windows.each_cons(2) { |(_, end1), (start2, _)| expect(start2).to eq end1 }
      end
    end

    context 'when import encounters errors' do
      before do
        allow(client).to receive(:fetch_comedy_events).and_raise(StandardError.new('API Error'))
        allow(notification_service).to receive(:notify_import_error)
        allow(metrics).to receive(:record_import)

        subject
      end

      it 'sends error notifications with serialized error data' do
        expect(notification_service).to have_received(:notify_import_error)
          .with hash_including(
            error: {
              message: 'API Error',
              class: 'StandardError',
              backtrace: kind_of(Array)
            },
            stats: hash_including(
              total_processed: 0,
              successful: 0,
              failed: 0,
              skipped: 0,
              rate_limited: 0,
              start_time: kind_of(Time),
              end_time: kind_of(Time),
              event: nil,
              source: 'ticketmaster'
            )
          )
      end

      it { expect(metrics).to have_received(:record_import)
             .with hash_including(total_processed: 0,
                                  successful: 0,
                                  failed: 0,
                                  skipped: 0,
                                  rate_limited: 0,
                                  start_time: kind_of(Time),
                                  end_time: kind_of(Time)) }

      it { expect(subject[:failed]).to eq(0) }
      it { expect(subject[:total_processed]).to eq(0) }
      it { expect(subject[:error]).to eq(class: 'StandardError', message: 'API Error') }
    end

    context 'when rate limit is hit' do
      before do
        error = Api::RateLimitError.new('Rate limit exceeded')
        allow(client).to receive(:fetch_comedy_events).and_raise(error)
        allow(notification_service).to receive(:notify_import_error)
        allow(notification_service).to receive(:notify_import_success)
        allow(metrics).to receive(:record_import)
        allow_any_instance_of(Kernel).to receive(:sleep)

        subject
      end

      describe 'handling rate limit errors and records stats' do
        it { expect(subject[:rate_limited]).to eq 1 }
        it { expect(subject[:successful]).to eq 0 }
        it { expect(subject[:total_processed]).to eq 0 }

        it { expect(notification_service).to have_received(:notify_import_error)
               .with hash_including(
                 error: {
                   message: 'Rate limit exceeded',
                   class: 'Api::RateLimitError',
                   backtrace: kind_of(Array)
                 },
                 stats: hash_including(
                   total_processed: 0,
                   successful: 0,
                   failed: 0,
                   skipped: 0,
                   rate_limited: 1,
                   start_time: kind_of(Time),
                   end_time: kind_of(Time),
                   event: nil,
                   source: 'ticketmaster'
                 )
               ) }

        it { expect(metrics).to have_received(:record_import).once
               .with hash_including(total_processed: 0,
                                    successful: 0,
                                    failed: 0,
                                    skipped: 0,
                                    rate_limited: 1,
                                    start_time: kind_of(Time),
                                    end_time: kind_of(Time)) }
      end
    end

    context 'when event is invalid' do
      let(:invalid_event) { { 'name' => 'Invalid Event' } } # Missing required fields
      let(:api_response_with_invalid_event) do
        {
          '_embedded' => {
            'events' => [ invalid_event ]
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

        subject
      end

      describe 'skipping invalid events' do
        it { expect(subject[:skipped]).to eq 1 }
        it { expect(subject[:successful]).to eq 0 }
        it { expect(subject[:total_processed]).to eq 1 }
        it { expect(metrics).to have_received(:record_import)
               .with hash_including(total_processed: 1,
                                    successful: 0,
                                    failed: 0,
                                    skipped: 1,
                                    rate_limited: 0,
                                    start_time: kind_of(Time),
                                    end_time: kind_of(Time)) }
      end

      describe 'notify_error method' do
        let(:error) { StandardError.new('Event processing error') }
        let(:event) { { 'name' => 'Test Event', 'id' => '123' } }

        it 'converts exceptions to serializable hashes' do
          # Call the notify_error method directly
          importer.send(:notify_error, error, event)

          # Verify the notification service was called with serialized data
          expect(notification_service).to have_received(:notify_import_error)
            .with(
              error: {
                message: 'Event processing error',
                class: 'StandardError',
                backtrace: kind_of(Array)
              },
              stats: hash_including(
                event: { 'name' => 'Test Event', 'id' => '123' },
                source: 'ticketmaster'
              )
            )
        end
      end
    end
  end
end
