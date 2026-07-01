require 'rails_helper'

RSpec.describe MonitorClient do
  describe '.report_run' do
    let(:http) { instance_double(Net::HTTP) }

    context 'when no API key is configured' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('MONITOR_API_KEY').and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:monitor, :api_key).and_return(nil)
      end

      it 'does not make an HTTP request' do
        expect(Net::HTTP).to_not receive(:start)
        described_class.report_run(script: 'ticketmaster_import', status: 'success')
      end
    end

    context 'when an API key is configured' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('MONITOR_API_KEY').and_return('test-key')
      end

      it 'posts run stats to the monitor with the API key header' do
        captured = nil
        allow(Net::HTTP).to receive(:start).and_yield(http)
        allow(http).to receive(:request) { |req| captured = req }

        described_class.report_run(
          script: 'ticketmaster_import', status: 'success',
          processed: 1021, failed: 35, skipped: 44
        )

        expect(captured['X-API-Key']).to eq 'test-key'
        body = JSON.parse(captured.body)
        expect(body).to include(
          'script' => 'ticketmaster_import',
          'status' => 'success',
          'processed' => 1021,
          'failed' => 35,
          'skipped' => 44
        )
      end

      it 'swallows network errors so a monitor outage never fails the import' do
        allow(Net::HTTP).to receive(:start).and_raise(SocketError.new('boom'))
        expect { described_class.report_run(script: 'ticketmaster_import', status: 'success') }
          .to_not raise_error
      end
    end
  end
end
