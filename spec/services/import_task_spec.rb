require 'rails_helper'

RSpec.describe ImportTask do
  let(:stats) { { total_processed: 5, successful: 4, failed: 1, skipped: 0, rate_limited: 0, error_samples: [ 'Show: oops' ] } }

  before { allow(MonitorClient).to receive(:report_run) }

  def run(result = stats, &block) = described_class.call(source: 'Eventfinda', script: 'eventfinda_import', &(block || -> { result }))

  it 'reports a good run, with its failed-event samples' do
    expect(run).to eq stats
    expect(MonitorClient).to have_received(:report_run).with(
      script: 'eventfinda_import', status: 'success', processed: 4, failed: 1, skipped: 0, errors: [ 'Show: oops' ]
    )
  end

  it 'reports a fatal error the importer recorded as a crash' do
    run(stats.merge(error: { class: 'Api::AuthenticationError', message: 'Invalid Eventfinda API credentials' }))
    expect(MonitorClient).to have_received(:report_run)
      .with(hash_including(status: 'crashed', errors: [ 'Api::AuthenticationError: Invalid Eventfinda API credentials', 'Show: oops' ]))
  end

  it 'treats a run that found nothing as a crash' do
    run(stats.merge(total_processed: 0, successful: 0, failed: 0, error_samples: []))
    expect(MonitorClient).to have_received(:report_run).with(hash_including(status: 'crashed', errors: [ 'Eventfinda returned no events' ]))
  end

  it 'accepts a run with nothing to do, for jobs that only work through what’s due' do
    described_class.call(source: 'Wikipedia bios', script: 'act_bios', allow_empty: true) { stats.merge(total_processed: 0, successful: 0, failed: 0, error_samples: []) }
    expect(MonitorClient).to have_received(:report_run).with(hash_including(script: 'act_bios', status: 'success', errors: []))
  end

    it 'reports an exception instead of raising it' do
    expect(run { raise ArgumentError, 'boom' }).to be_nil
    expect(MonitorClient).to have_received(:report_run)
      .with(hash_including(script: 'eventfinda_import', status: 'crashed', errors: array_including('ArgumentError: boom')))
  end
end
