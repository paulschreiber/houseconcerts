class SettingsForm
  class Email < SettingsForm
    # The part of an address before the @ (the domain is fixed): letters,
    # numbers and the symbols email allows, with single dots between them.
    LOCAL_PART = %r{\A[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*\z}
    # A name in a From header: no line breaks or other control characters, and
    # nothing that would end or start an address.
    SENDER_NAME = /\A[^\p{Cntrl}<>"]+\z/
    # A line of the sign-off: no control characters (line breaks split the
    # lines), invisible formatting characters such as right-to-left overrides,
    # or Unicode line and paragraph separators.
    SIGN_OFF_LINE = /\A[^\p{Cntrl}\p{Cf}\u2028\u2029]*\z/
    HOUR = /\A(?:[01]\d|2[0-3]):00\z/

    setting :invites_from_first_name, "organization.invites_from_first_name"
    setting :invites_from_last_name, "organization.invites_from_last_name"
    setting :invites_from_email, "organization.invites_from_email"
    setting :confirms_from_name, "organization.confirms_from_name"
    setting :confirms_from_email, "organization.confirms_from_email"
    setting :guest_sign_off, "guest_sign_off", :multiline
    setting :reminder_days, "reminders.days_before", :integer
    setting :reminder_time, "reminders.hour", from: ->(hour) { format("%02d:00", hour) }, to: ->(time) { time.to_i }

    validates :invites_from_first_name, :invites_from_last_name, :confirms_from_name, presence: true, length: { maximum: 100 }
    validates :invites_from_first_name, :invites_from_last_name, :confirms_from_name, format: { with: SENDER_NAME, message: :not_a_name }, allow_blank: true
    validates :invites_from_email, :confirms_from_email, presence: true, length: { maximum: 64 }
    validates :invites_from_email, :confirms_from_email, format: { with: LOCAL_PART, message: :not_an_address_start }, allow_blank: true
    validates :guest_sign_off, length: { maximum: 500 }
    validate :sign_off_is_plain_text
    validates :reminder_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 30 }
    validates :reminder_time, format: { with: HOUR, message: :not_a_whole_hour }

    private

      def sign_off_is_plain_text
        errors.add(:guest_sign_off, :not_plain_text) unless guest_sign_off.to_s.split("\n").all? { |line| line.match?(SIGN_OFF_LINE) }
      end
  end
end
