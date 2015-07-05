class RSVP < ActiveRecord::Base
  belongs_to :show

  before_save :downcase_email
  before_save :update_confirmation_status

  validates :first_name, presence: true, mixed_case: true
  validates :last_name, presence: true, mixed_case: true
  validates :email, presence: true, email: true
  validates :postcode, postal_code: { country: HC_CONFIG.default_country }
  validates :seats, numericality: {
    only_integer: true,
    greater_than_or_equal_to: HC_CONFIG.show.min_seats,
    less_than_or_equal_to: HC_CONFIG.show.max_seats
  }
  validates :response, inclusion: { in: HC_CONFIG.rsvp.response.values }

  def update_confirmation_status
    if self.confirmed_changed? and self.status == HC_CONFIG.rsvp.confirmed[:yes]
      self.confirmed_at = DateTime.now
    end
  end

end
