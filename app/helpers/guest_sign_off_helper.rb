# The sign-off that ends every email guests get from the host: the guest_sign_off
# setting, plain text shown with its line breaks, or the host's first name
# while it's blank.
module GuestSignOffHelper
  def guest_sign_off
    simple_format(h(Settings.guest_sign_off.presence || Settings.organization.invites_from_first_name), {}, sanitize: false)
  end
end
