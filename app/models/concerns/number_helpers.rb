module NumberHelpers
  extend ActiveSupport::Concern

  def phone_number_twilio
    "+1#{phone_number.gsub(/[^0-9]+/, '')}" if phone_number.present?
  end
end
