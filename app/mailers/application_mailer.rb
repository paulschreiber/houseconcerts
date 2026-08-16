class ApplicationMailer < ActionMailer::Base
  default from: -> { formatted_address(Settings.invites_from_name, Settings.invites_from_email) }
  layout "mailer"

  private

    def formatted_address(name, username)
      Mail::Address.new("#{username}@#{Settings.domain}").tap { |address| address.display_name = name }.format
    end
end
