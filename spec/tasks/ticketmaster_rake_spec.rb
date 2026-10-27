require 'rails_helper'
require 'rake'

RSpec.describe 'ticketmaster:daily_import' do
  let(:importer) { instance_double(Api::TicketmasterImporter) }
  let(:stats) { { total_processed: 120, successful: 100, failed: 0, skipped: 20, rate_limited: 0, error_samples: [] } }

  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'ticketmaster:daily_import' } }

  before do
    Rake::Task['ticketmaster:daily_import'].reenable
    allow(Api::TicketmasterImporter).to receive(:new).and_return(importer)
    allow(importer).to receive(:import_events).and_return(stats)
    allow(GigCleanup).to receive(:call)
    allow(MonitorClient).to receive(:report_run)
  end

  subject(:run_task) { Rake::Task['ticketmaster:daily_import'].invoke }

  it 'reports a healthy run as success' do
    run_task
    expect(MonitorClient).to have_received(:report_run)
      .with(hash_including(script: 'ticketmaster_import', status: 'success', processed: 100, errors: []))
  end

  it 'runs the cleanup' do
    run_task
    expect(GigCleanup).to have_received(:call)
  end

  context 'when the importer swallowed a fatal error' do
    let(:stats) { super().merge(error: { class: 'Api::AuthenticationError', message: 'Invalid API key' }) }

    it 'reports the run as crashed with the error' do
      run_task
      expect(MonitorClient).to have_received(:report_run)
        .with(hash_including(status: 'crashed', errors: [ 'Api::AuthenticationError: Invalid API key' ]))
    end
  end

  context 'when Ticketmaster returned nothing at all' do
    let(:stats) { { total_processed: 0, successful: 0, failed: 0, skipped: 0, rate_limited: 0, error_samples: [] } }

    it 'reports the run as crashed' do
      run_task
      expect(MonitorClient).to have_received(:report_run)
        .with(hash_including(status: 'crashed', errors: [ 'Ticketmaster returned no events' ]))
    end
  end

  context 'when some events failed' do
    let(:stats) { super().merge(failed: 2, error_samples: [ 'Show A: boom', 'Show B: bang' ]) }

    it 'passes the sampled failures to the monitor' do
      run_task
      expect(MonitorClient).to have_received(:report_run)
        .with(hash_including(status: 'success', failed: 2, errors: [ 'Show A: boom', 'Show B: bang' ]))
    end
  end

  context 'when the cleanup fails' do
    before { allow(GigCleanup).to receive(:call).and_raise(ActiveRecord::StatementInvalid, 'boom') }

    it 'still reports the import, noting the cleanup failure' do
      run_task
      expect(MonitorClient).to have_received(:report_run)
        .with(hash_including(status: 'success', errors: [ 'Cleanup failed: ActiveRecord::StatementInvalid: boom' ]))
    end
  end
end
