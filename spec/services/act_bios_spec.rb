require 'rails_helper'

RSpec.describe ActBios do
  include ActiveSupport::Testing::TimeHelpers

  let(:client) { instance_double(Api::WikipediaClient) }

  def item(title, *occupations)
    {
      'sitelinks' => { 'enwiki' => { 'title' => title } },
      'claims' => { 'P106' => occupations.map { |id| { 'mainsnak' => { 'datavalue' => { 'value' => { 'id' => id } } } } } }
    }
  end

  def run(**options) = described_class.new(client:, **options).call

  let!(:rose) { create :act, name: 'Rose Matafeo' }
  before { create :gig, acts: [ rose ], start_time: 1.week.from_now, end_time: nil }

  it 'stores the comedian’s article lead, skipping a namesake' do
    allow(client).to receive(:items_for_titles).with([ 'Rose Matafeo', 'Rose Matafeo (comedian)' ])
      .and_return([ item('Rose Matafeo (footballer)', 'Q937857'), item('Rose Matafeo', 'Q33999', 'Q245068') ])
    allow(client).to receive(:summary).with('Rose Matafeo').and_return(text: 'Rose is a comedian.', url: 'https://en.wikipedia.org/wiki/Rose_Matafeo')

    expect(run).to include(total_processed: 1, successful: 1, skipped: 0)
    expect(rose.reload).to have_attributes(bio: 'Rose is a comedian.', bio_url: 'https://en.wikipedia.org/wiki/Rose_Matafeo', bio_checked_at: be_present)
  end

  it 'leaves an act without one when no article is about a comedian, and checks again a month later' do
    allow(client).to receive(:items_for_titles).and_return([ item('Rose Matafeo', 'Q33999') ])

    expect(run).to include(skipped: 1)
    expect(rose.reload.bio).to be_nil
    expect(run[:total_processed]).to eq 0

    create :gig, acts: [ rose ], start_time: 3.months.from_now, end_time: nil
    travel(29.days) { expect(described_class.new(client:).due_acts).to be_empty }
    travel(31.days) { expect(described_class.new(client:).due_acts).to eq [ rose ] }
  end

  it 'only looks up people with gigs coming up, busiest first, a batch at a time' do
    busy = create :act, name: 'Guy Montgomery'
    create_list :gig, 2, acts: [ busy ], start_time: 1.week.from_now, end_time: nil
    create :gig, acts: [ create(:act, name: 'Laugh Factory Las Vegas') ], start_time: 1.week.from_now, end_time: nil
    create :act, name: 'Past Comedian'

    expect(described_class.new(client:).due_acts).to eq [ busy, rose ]
    expect(described_class.new(client:, limit: 1).due_acts).to eq [ busy ]
  end

  it 'stops for the night when Wikimedia asks it to slow down' do
    create :gig, acts: [ create(:act, name: 'Guy Montgomery') ], start_time: 1.week.from_now, end_time: nil
    allow(client).to receive(:items_for_titles).and_raise(Api::RateLimitError, 'slow down')

    expect(run).to include(total_processed: 1, rate_limited: 1, error: { class: 'Api::RateLimitError', message: 'slow down' })
    expect(Act.where.not(bio_checked_at: nil)).to be_empty
  end

  it 'counts an act that fails and carries on' do
    create :gig, acts: [ create(:act, name: 'Guy Montgomery') ], start_time: 2.weeks.from_now, end_time: nil
    allow(client).to receive(:items_for_titles).with(array_including('Rose Matafeo')).and_raise(Api::ApiError, 'Wikimedia returned 500')
    allow(client).to receive(:items_for_titles).with(array_including('Guy Montgomery')).and_return([])

    expect(run).to include(total_processed: 2, failed: 1, skipped: 1, error_samples: [ 'Rose Matafeo: Api::ApiError: Wikimedia returned 500' ])
  end
end
