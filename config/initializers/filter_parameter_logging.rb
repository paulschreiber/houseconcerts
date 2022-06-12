# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
  :password, :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn
]

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'RSVP'
end
