# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:password]

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'RSVP'
end
