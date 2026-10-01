class MailingListMailer < ApplicationMailer
  # Sent when someone who unsubscribed (or whose address stopped working)
  # signs up again; they're only added back once they click the link.
  def rejoin(person)
    @person = person
    @rejoin_url = mailing_list_rejoin_url(uniqid: person.uniqid)
    mail(to: person.email_address_with_name, subject: "Confirm you want to rejoin the #{Settings.site_name} mailing list")
  end
end
