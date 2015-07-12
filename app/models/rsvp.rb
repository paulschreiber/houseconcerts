class RSVP < ActiveRecord::Base
  belongs_to :show

  before_save :downcase_email
  before_save :update_confirmation_date

  validates :first_name, presence: true, mixed_case: true
  validates :last_name, presence: true, mixed_case: true
  validates :email, email: true
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }
  validates :seats, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.show.min_seats,
    less_than_or_equal_to: HC_CONFIG.show.max_seats
  }
  validates :response, inclusion: { in: HC_CONFIG.rsvp.response }

  def update_confirmation_date
    if self.confirmed_changed? and response == HC_CONFIG.rsvp.confirmed[:yes]
      self.confirmed_at = DateTime.now
    end
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

end
