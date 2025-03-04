class TextMessagesMailer < ApplicationMailer
  def notify(sender, body)
    @sender = sender
    @body = body

    mail(to: HC_CONFIG.invites_from,
         subject: "SMS from #{@sender}",
         delivery_method: delivery_method,
         delivery_method_options: delivery_options)
  end
end
