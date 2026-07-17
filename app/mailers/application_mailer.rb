class ApplicationMailer < ActionMailer::Base
  default from: Settings.invites_from
  layout "mailer"
end
