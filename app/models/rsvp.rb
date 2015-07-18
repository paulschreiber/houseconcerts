class RSVP < ActiveRecord::Base
  belongs_to :show

  before_save :downcase_email
  before_save :update_confirmation_date
  before_save :clear_seats_if_no

  validates :first_name, presence: true, mixed_case: true
  validates :last_name, presence: true, mixed_case: true
  validates :email, email: true
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }, allow_blank: true
  validates :seats, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.show.min_seats,
    less_than_or_equal_to: HC_CONFIG.show.max_seats
  }, unless: :no?
  validates :response, inclusion: { in: HC_CONFIG.rsvp.response }

  def update_confirmation_date
    return if !self.confirmed_changed? || !confirmed?

    self.confirmed_at = DateTime.now
  end

  def clear_seats_if_no
    return if self.yes?

    self.seats = 0
  end

  # define .yes?, .no?
  HC_CONFIG.rsvp.response.each do |value|
    define_method("#{value.downcase}?") { response == value }
  end

  def confirmed?
    confirmed == HC_CONFIG.rsvp.confirmed[:yes]
  end

  def unconfirmed?
    confirmed == HC_CONFIG.rsvp.confirmed[:no]
  end

  def waitlisted?
    confirmed == HC_CONFIG.rsvp.confirmed[:waitlisted]
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end
end
