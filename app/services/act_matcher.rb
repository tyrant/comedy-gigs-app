# Finds known comedians named in an event's title, for sources (Eventfinda)
# that don't list performers: "Urzila Carlson - Fatty On a Yacht" -> Urzila Carlson.
#
# It only links acts we already know, by their full name as whole words, and
# only acts that look like people: single-word names are too easily a common
# word, and Ticketmaster lists plenty of "acts" like "Comedy Night" or "Stand
# Up Comedy" that would match any number of titles. Descriptions mention
# people in passing ("in the vein of Greg Davies"), so they're left alone.
class ActMatcher
  GENERIC_WORDS = %w[
    cabaret club comedian comedians comedic comedy comic comics fest festival funny gala improv improvised
    joke jokes laugh laughs live mic night nights open podcast presents roast series show shows showcase
    sketch special stand standup tour
  ].to_set.freeze

  MAX_NAME_WORDS = 5

  def initialize
    @acts = index_acts
  end

  # The acts named in the title, in the order they appear
  def acts_in(title)
    words = normalize(title).split
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
        key = normalize(name)
        words = key.split
        next if words.size < 2 || words.size > MAX_NAME_WORDS || words.any? { |word| GENERIC_WORDS.include?(word) }

        index[key] = id # later rows (more gigs) win
      end
  end

  # "Dara Ó Briain: Re-Creation" -> "dara o briain re creation"
  def normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, " ").squish
  end
end
