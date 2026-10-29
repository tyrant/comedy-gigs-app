require 'rails_helper'
require 'rake'

RSpec.describe 'import:all' do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'import:all' } }

  let(:stats) { { total_processed: 3, successful: 3, failed: 0, skipped: 0, rate_limited: 0, error_samples: [] } }
  let(:order) { [] }

  before do
    %w[import:all ticketmaster:daily_import eventfinda:daily_import tours:assemble].each { |name| Rake::Task[name].reenable }
    { Api::TicketmasterImporter => :ticketmaster, Api::EventfindaImporter => :eventfinda }.each do |klass, name|
      importer = instance_double(klass)
      allow(klass).to receive(:new).and_return(importer)
      allow(importer).to receive(:import_events) { order << name; stats }
    end
    allow(GigCleanup).to receive(:call) { order << :cleanup; { old_gigs_removed: 40, cancelled_gigs_removed: 2 } }
    allow(TourFinder).to receive(:call) { order << :tours; { tours: 12, tour_gigs: 80 } }
    allow(MonitorClient).to receive(:report_run)
  end

  subject(:run_task) { Rake::Task['import:all'].invoke }

  it 'imports each source, reporting each, then prunes old gigs and assembles tours' do
    run_task
    expect(order).to eq %i[ticketmaster eventfinda cleanup tours]
    expect(MonitorClient).to have_received(:report_run).with(hash_including(script: 'ticketmaster_import', status: 'success'))
    expect(MonitorClient).to have_received(:report_run).with(hash_including(script: 'eventfinda_import', status: 'success'))
  end

  it 'still runs the other source when one crashes' do
    allow(Api::TicketmasterImporter).to receive(:new).and_raise(Api::AuthenticationError, 'Missing Ticketmaster API key')
    run_task
    expect(order).to eq %i[eventfinda cleanup tours]
    expect(MonitorClient).to have_received(:report_run).with(hash_including(script: 'ticketmaster_import', status: 'crashed'))
  end

  it 'reports how many gigs the cleanup removed' do
    run_task
    expect(MonitorClient).to have_received(:report_run).with(script: 'gig_cleanup', status: 'success', processed: 42)
  end

  it 'reports a failed cleanup' do
    allow(GigCleanup).to receive(:call).and_raise(ActiveRecord::StatementInvalid, 'boom')
    run_task
    expect(MonitorClient).to have_received(:report_run)
      .with(script: 'gig_cleanup', status: 'crashed', errors: [ 'ActiveRecord::StatementInvalid: boom' ])
  end

  it 'reports the tours found' do
    run_task
    expect(MonitorClient).to have_received(:report_run).with(script: 'tours', status: 'success', processed: 12)
  end

  it 'still assembles tours when the cleanup fails, and reports a failed assembly' do
    allow(GigCleanup).to receive(:call).and_raise(ActiveRecord::StatementInvalid, 'boom')
    allow(TourFinder).to receive(:call).and_raise(ActiveRecord::StatementInvalid, 'bust')
    run_task
    expect(MonitorClient).to have_received(:report_run)
      .with(script: 'tours', status: 'crashed', errors: [ 'ActiveRecord::StatementInvalid: bust' ])
  end
end
