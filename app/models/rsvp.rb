class RSVP < ActiveRecord::Base
  belongs_to :show

  before_save :downcase_email
  before_save :update_confirmation_date
  before_save :clear_seats_if_no

  # From https://stackoverflow.com/a/1126031/135850
  default_value_for :uniqid do
    rand(2821109907456).to_s(36)
  end

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
  validates :show_id, inclusion: { in: ->_ { Show.all.collect(&:id) } }

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
    define_method("#{value}?") { response == value }
  end

  # define .yes!, .no!
  # use update_attribute_s_ so the before_save actions fire
  HC_CONFIG.rsvp.response.each do |value|
    define_method("#{value}!") { update_attributes(response: value) }
  end

  def confirm!
    update_attribute(:confirmed, 'yes') if yes?
  end

  def waitlist!
    update_attribute(:confirmed, 'waitlisted') if yes?
  end

  def confirmed?
    confirmed == 'yes'
  end

  def unconfirmed?
    confirmed == 'no' || confirmed.empty?
  end

  def waitlisted?
    confirmed == 'waitlisted'
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def create_person
    return if Person.where(email: email).first

    Person.create(first_name: first_name, last_name: last_name, email: email, postcode: postcode, notes: "RSVPd for show #{show.slug}")
  end

  def email_address_with_name
    return unless email.present?
    if full_name.present?
      "\"#{full_name}\" <#{email}>"
    else
      email
    end
  end
end
