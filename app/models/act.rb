class Act < ApplicationRecord
  include Sourced

  before_save -> { self.match_key = MatchKey.act(name) }, if: -> { name_changed? || match_key.nil? }
  # Remove the ActionView helper as it won't work properly in API contexts

  # Relationships
  has_and_belongs_to_many :gigs

  # Validations
  validates :name, presence: true

  # Ensure social_links and images are always hashes
  attribute :social_links, :jsonb, default: -> { {} }
  attribute :images, :jsonb, default: -> { {} }

  # Scopes
  scope :performing_between, ->(start_date, end_date) {
    joins(:gigs)
      .where("gigs.start_time >= ? AND gigs.start_time <= ?",
             start_date.beginning_of_day,
             end_date.end_of_day)
      .distinct
  }

  # The kinds of official link shown, in order, and the sites each must be on
  # (a homepage can be anywhere). Ticketmaster gives Twitter as a URL or a
  # bare "@handle".
  OFFICIAL_LINK_KINDS = {
    "homepage" => nil,
    "instagram" => %w[instagram.com],
    "tiktok" => %w[tiktok.com],
    "youtube" => %w[youtube.com youtu.be],
    "twitter" => %w[twitter.com x.com],
    "facebook" => %w[facebook.com],
    "spotify" => %w[open.spotify.com]
  }.freeze

  HANDLE_PROFILES = { "twitter" => "https://x.com/", "instagram" => "https://www.instagram.com/", "tiktok" => "https://www.tiktok.com/@" }.freeze

  # [ { kind:, url: }, ... ]: links that go to a page of the act's own, on
  # the site they claim to be. A bare "youtube.com/playlist" goes nowhere.
  def official_links
    OFFICIAL_LINK_KINDS.filter_map do |kind, hosts|
      url = official_url(kind, social_links[kind].to_s.strip)
      uri = URI.parse(url) if url
      next unless uri.is_a?(URI::HTTP) && uri.host.present?
      next if hosts && hosts.none? { |host| uri.host == host || uri.host.end_with?(".#{host}") }
      next if hosts && (uri.path.delete("/").blank? || (uri.path == "/playlist" && uri.query.blank?))

      { kind:, url: }
    rescue URI::InvalidURIError
      nil
    end
  end

  # Use a placeholder image that will definitely work
  # For production, you should use your own hosted image
  IMAGE_PLACEHOLDER = "/images/comedian_placeholder.png"

  # Acts are shown as small avatars, so default to the thumbnail
  def primary_image_url(size = "thumb")
    return IMAGE_PLACEHOLDER if images.blank?

    # Try to find an image with the requested size
    if images[size].present?
      images[size]
    # Fall back to the first available size
    elsif images.values.first.present?
      images.values.first
    else
      IMAGE_PLACEHOLDER
    end
  end

  private

  def official_url(kind, value)
    if value.match?(%r{\Ahttps?://}i) then value
    elsif value.match?(/\A(@[\w.]+|\w+)\z/) && HANDLE_PROFILES[kind] then HANDLE_PROFILES[kind] + value.delete_prefix("@")
    elsif value.match?(/\A(www\.)?[\w-]+(\.[\w-]+)+(\/\S*)?\z/) then "https://#{value}"
    end
  end
end
