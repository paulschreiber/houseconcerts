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

  # A password reset removes every passkey, so resetting the password also
  # locks out anyone who added their own passkey with a stolen session.
  def reset_password(new_password, new_password_confirmation)
    reset = super
    passkeys.destroy_all if reset
    reset
  end
end
