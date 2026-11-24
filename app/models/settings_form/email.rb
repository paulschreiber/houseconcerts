class SettingsForm
  class Email < SettingsForm
    # The part of an address before the @ (the domain is fixed): letters,
    # numbers and the symbols email allows, with single dots between them.
    LOCAL_PART = %r{\A[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*\z}
    # A name in a From header can't have anything that would end or start an
    # address. (Line breaks and other control characters are cleaned out.)
    SENDER_NAME = /\A[^<>"]+\z/
    HOUR = /\A(?:[01]\d|2[0-3]):00\z/

    setting :invites_from_first_name, "organization.invites_from_first_name"
    setting :invites_from_last_name, "organization.invites_from_last_name"
    setting :invites_from_email, "organization.invites_from_email"
    setting :confirms_from_name, "organization.confirms_from_name"
    setting :confirms_from_email, "organization.confirms_from_email"
    setting :guest_sign_off, "guest_sign_off", :text
    setting :reminder_days, "reminders.days_before", :integer
    setting :reminder_time, "reminders.hour", from: ->(hour) { format("%02d:00", hour) }, to: ->(time) { time.to_i }

    validates :invites_from_first_name, :invites_from_last_name, :confirms_from_name, presence: true, length: { maximum: 100 }
    validates :invites_from_first_name, :invites_from_last_name, :confirms_from_name, format: { with: SENDER_NAME, message: :not_a_name }, allow_blank: true
    validates :invites_from_email, :confirms_from_email, presence: true, length: { maximum: 64 }
    validates :invites_from_email, :confirms_from_email, format: { with: LOCAL_PART, message: :not_an_address_start }, allow_blank: true
    validates :guest_sign_off, length: { maximum: 500 }
    validates :reminder_days, numericality: { in: 0..30 }
    validates :reminder_time, format: { with: HOUR, message: :not_a_whole_hour }
  end
end
