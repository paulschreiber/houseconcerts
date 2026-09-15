module RsvpsHelper
  # "Two seats"/"seats have" for more than one seat, or the given singular
  # phrase ("a seat"/"seat has") for exactly one.
  def seat_count_phrase(seats_reserved, plural_suffix, singular_phrase)
    seats_reserved > 1 ? "#{seats_reserved.humanize} #{plural_suffix}" : singular_phrase
  end
end
