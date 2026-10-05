# Security notices sent to an admin about their own account.
class AdminMailer < ApplicationMailer
  layout "admin_notification"

  default from: -> { formatted_address(Settings.confirms_from_name, Settings.confirms_from_email) }

  def passkey_added(admin, passkey_name, ip_address)
    @passkey_name = passkey_name
    @ip_address = ip_address
    mail(to: admin.email, subject: "A passkey was added to your #{Settings.site_name} admin account")
  end

  def passkey_removed(admin, passkey_name, ip_address)
    @passkey_name = passkey_name
    @ip_address = ip_address
    mail(to: admin.email, subject: "A passkey was removed from your #{Settings.site_name} admin account")
  end
end
