class Admin < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable and :omniauthable
  devise :database_authenticatable, :passkey_authenticatable,
         :recoverable, :rememberable, :timeoutable, :trackable, :validatable

  # Every sign-in (password, passkey, or after a password reset) is
  # remembered for remember_for, so closing the browser doesn't sign an
  # admin out. Signing out on any device, or timing out, forgets them on
  # every device (expire_all_remember_me_on_sign_out).
  def remember_me = true # rubocop:disable Naming/PredicateMethod -- Devise's name

  # Devise mail (password reset instructions) goes out in the background.
  # Delivering it inline made a reset request for a real admin's email
  # measurably slower than one for an unknown email, undoing paranoid mode.
  def send_devise_notification(notification, *)
    devise_mailer.send(notification, self, *).deliver_later
  end

  # Changing the email cancels any password link (Devise clears the token), so
  # an admin who hasn't signed in yet, e.g. after a typo in their email is
  # fixed, gets a new one at the new address. Setting the token saves again,
  # but without an email change.
  after_update_commit :send_welcome_instructions, if: -> { saved_change_to_email? && sign_in_count.zero? }

  # Emails a new admin a link to set their password. It's a password reset
  # link, so it expires after reset_password_within, and "Forgot your
  # password?" sends a new one.
  def send_welcome_instructions
    AdminMailer.welcome(self, set_reset_password_token).deliver_later
  end

  # A password reset removes every passkey, so resetting the password also
  # locks out anyone who added their own passkey with a stolen session.
  def reset_password(new_password, new_password_confirmation)
    reset = super
    passkeys.destroy_all if reset
    reset
  end
end
