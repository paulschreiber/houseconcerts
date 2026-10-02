# Marks a browser an admin has signed in from with a long-lived encrypted
# cookie. Anyone who knows an admin's email can use up the per-email sign-in
# throttle (config/initializers/rack_attack.rb) and lock that admin out of
# password sign-in. Sign-ins from a browser with this cookie for that email
# skip the per-email throttle and get their own per-device one instead, so an
# attacker can only lock out browsers the admin hasn't signed in from.
#
# The cookie only affects throttling, not authentication, and it can't be
# forged without secret_key_base. Set on every successful admin sign-in
# (password, passkey, or after a password reset) by the Warden hook in
# config/initializers/devise.rb.
module AdminTrustedDevice
  COOKIE = :admin_trusted_device

  def self.remember(request, admin)
    request.cookie_jar.encrypted[COOKIE] = {
      value: { "email" => admin.email.to_s.strip.downcase, "id" => SecureRandom.uuid },
      expires: 1.year,
      httponly: true,
      same_site: :lax
    }
  end

  # The device's id if this browser has the cookie for this (normalized)
  # email, else nil.
  def self.device_id(request, email)
    return if email.blank?

    data = request.cookie_jar.encrypted[COOKIE]
    data["id"] if data.is_a?(Hash) && data["email"] == email
  end
end
