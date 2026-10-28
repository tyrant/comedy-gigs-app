# Finds known comedians named in an event's title, for sources (Eventfinda)
# that don't list performers: "Urzila Carlson - Fatty On a Yacht" -> Urzila Carlson.
#
# It only links acts we already know, by their full name as whole words, and
# only acts that look like people: single-word names are too easily a common
# word, and Ticketmaster lists plenty of "acts" like "Comedy Night" or "Stand
# Up Comedy" that would match any number of titles. Descriptions mention
# people in passing ("in the vein of Greg Davies"), so they're left alone.
class ActMatcher
  MAX_NAME_WORDS = 5

  def initialize
    @acts = index_acts
  end

  # The acts named in the title, in the order they appear
  def acts_in(title)
    words = MatchKey.normalize(title).split
    found = []

    words.each_index do |start|
      MAX_NAME_WORDS.downto(2) do |length|
        act_id = @acts[words[start, length].join(" ")] if start + length <= words.size
        next unless act_id

        found << act_id
        break
      end
    end

    Act.where(id: found.uniq).sort_by { |act| found.index(act.id) }
  end

  private

  # Normalised name -> act ID, keeping the act with the most gigs when two share a name
  def index_acts
    Act.left_joins(:gigs).group(:id).order(Arel.sql("COUNT(gigs.id) ASC"), id: :desc).pluck(:id, :name)
      .each_with_object({}) do |(id, name), index|
        next unless MatchKey.person_name?(name, max_words: MAX_NAME_WORDS)

        index[MatchKey.act(name)] = id # later rows (more gigs) win
      end
  end
end
