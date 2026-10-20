# The contact details a person and their RSVPs share. RSVPs are matched to
# people by email, so both models must store email the same way.
module ContactDetails
  extend ActiveSupport::Concern

  ATTRIBUTES = %i[first_name last_name email phone_number postcode].freeze
  NORMALIZE_EMAIL = ->(email) { email.strip.downcase }

  included do
    normalizes :email, with: NORMALIZE_EMAIL

    # The format check counts letters, not characters, so "X." doesn't pass
    # the two-character minimum.
    validates :first_name, :last_name, presence: true, mixed_case: true, length: { minimum: 2, maximum: 100 },
                                       format: { with: /\p{L}.*\p{L}/, allow_blank: true }
    validates :email, email: true, length: { maximum: 200 }
    validates :phone_number, phone: { country: Settings.default_country, set: true }, length: { maximum: 30 }, allow_blank: true
    validates :postcode, postal_code: { country: Settings.default_country }, length: { maximum: 10 }, allow_blank: true
  end

  def contact_attributes
    slice(*ATTRIBUTES)
  end
end
