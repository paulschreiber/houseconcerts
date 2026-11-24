class SettingsForm
  class Shows < SettingsForm
    setting :arrival_minutes, "show.arrival_minutes", :integer
    setting :duration, "show.duration", :integer
    setting :availability_cutoff_hours, "show.availability_cutoff_hours", :integer
    setting :max_seats, "show.max_seats", :integer
    setting :overbook_seats, "show.overbook_seats", :integer
    setting :waitlist_capacity, "show.waitlist_capacity", :integer
    setting :min_price, "show.min_price", :integer
    setting :max_price, "show.max_price", :integer
    setting :min_capacity, "venue.min_capacity", :integer
    setting :max_capacity, "venue.max_capacity", :integer
    setting :notify_rsvp, "notify_rsvp", :boolean, from: ->(value) { value.present? }, to: ->(notify) { notify ? "yes" : "" }

    validates :arrival_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 600 }
    validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 24 }
    validates :availability_cutoff_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 720 }
    validates :max_seats, numericality: { only_integer: true, greater_than_or_equal_to: ->(_form) { Defaults.show.min_seats }, less_than_or_equal_to: 100 }
    validates :overbook_seats, :waitlist_capacity, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000 }
    validates :min_price, :max_price, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100_000 }
    validates :min_capacity, :max_capacity, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 10_000 }
    validate :minimums_are_not_above_maximums

    private

      def minimums_are_not_above_maximums
        errors.add(:min_price, :above_maximum) if min_price && max_price && min_price > max_price
        errors.add(:min_capacity, :above_maximum) if min_capacity && max_capacity && min_capacity > max_capacity
      end
  end
end
