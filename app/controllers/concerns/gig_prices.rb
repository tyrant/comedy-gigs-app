# What a gig's tickets cost, for the API's gig listings: a range (null when no
# source gives one), and the ticket types where Eventfinda lists them
module GigPrices
  private

  def price_json(gig)
    return nil if gig.price_min.nil?

    { min: gig.price_min.to_f, max: (gig.price_max || gig.price_min).to_f, currency: gig.currency }
  end

  def tiers_json(gig)
    gig.ticket_tiers.map { |tier| tier.slice("name", "price", "sold_out", "few_left") }
  end

  # Some ticket type is nearly gone, and the gig isn't sold out
  def few_left?(gig)
    gig.status != "sold_out" && gig.ticket_tiers.any? { |tier| tier["few_left"] && !tier["sold_out"] }
  end

  def prices_json(gig) = { price: price_json(gig), tiers: tiers_json(gig), few_left: few_left?(gig) }
end
