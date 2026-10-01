class Admin < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable and :omniauthable
  devise :database_authenticatable, :passkey_authenticatable,
         :recoverable, :rememberable, :timeoutable, :trackable, :validatable

  # Devise mail (password reset instructions) goes out in the background.
  # Delivering it inline made a reset request for a real admin's email
  # measurably slower than one for an unknown email, undoing paranoid mode.
  def send_devise_notification(notification, *)
    devise_mailer.send(notification, self, *).deliver_later
  end

  # A password reset removes every passkey, so resetting the password also
  # locks out anyone who added their own passkey with a stolen session.
  def reset_password(new_password, new_password_confirmation)
    super.tap { |reset| passkeys.destroy_all if reset }
  end
end
