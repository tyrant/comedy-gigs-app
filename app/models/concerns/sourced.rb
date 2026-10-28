# Records that sources describe: they keep each source's IDs as SourceLinks
module Sourced
  extend ActiveSupport::Concern

  included do
    has_many :source_links, as: :linkable, dependent: :delete_all
  end

  class_methods do
    def linked_to(source, external_id)
      where(id: SourceLink.where(linkable_type: name, source:, external_id: external_id.to_s).select(:linkable_id))
    end
  end

  def link_to!(source, external_id)
    source_links.find_or_create_by!(source:, external_id: external_id.to_s)
  end

  # { "ticketmaster" => ["KovZ1"], "eventfinda" => ["501"] }
  def source_ids
    source_links.group_by(&:source).transform_values { |links| links.map(&:external_id) }
  end
end
