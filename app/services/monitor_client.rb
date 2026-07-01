require "net/http"
require "json"

class MonitorClient
  MONITOR_URL = "https://monitor.mikeyclarke.co.nz/api/run".freeze

  def self.report_run(script:, status:, processed: 0, failed: 0, skipped: 0, errors: [])
    api_key = ENV["MONITOR_API_KEY"].presence || Rails.application.credentials.dig(:monitor, :api_key)
    unless api_key
      Rails.logger.info "MONITOR_API_KEY not set — skipping monitor report"
      return
    end

    uri = URI(MONITOR_URL)
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "X-API-Key" => api_key)
    request.body = {
      script: script,
      status: status,
      processed: processed,
      failed: failed,
      skipped: skipped,
      errors: errors,
      ran_at: Time.current.utc.iso8601
    }.to_json

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      http.request(request)
    end
  rescue StandardError => e
    Rails.logger.warn "Monitor report failed (non-fatal): #{e.message}"
  end
end
