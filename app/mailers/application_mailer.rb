class ApplicationMailer < ActionMailer::Base
  default from: HC_CONFIG.invites_from
  layout 'mailer'
end
