class SettingsForm
  # An integer that doesn't turn text into 0 ("soon" casts to nil, which fails
  # the number validation, instead of becoming 0).
  class WholeNumber < ActiveModel::Type::Integer
    def cast(value)
      return nil if value.is_a?(String) && !value.match?(/\A\s*-?\d+\s*\z/)

      super
    end
  end
end
