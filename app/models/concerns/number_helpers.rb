module NumberHelpers
  extend ActiveSupport::Concern

  def phone_number_twilio
    "+1#{phone_number.gsub(/[^0-9]+/, '')}" if phone_number.present?
  end

  def phone_number_formatted(number)
    # ignore non-North American phone numbers
    return number if number.size != 12 and number[0..1] != "+1"

    # strip off +1
    number = number[2..]

    area_code = number[0..2]
    exchange = number[3..5]
    sln = number[6..9]

    "(#{area_code}) #{exchange}-#{sln}"
  end
end
