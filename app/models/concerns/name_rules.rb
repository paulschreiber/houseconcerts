module NameRules
  extend ActiveSupport::Concern

  included do
    # The format check counts letters, not characters, so "X." doesn't pass
    # the two-character minimum.
    validates :first_name, :last_name, presence: true, mixed_case: true, length: { minimum: 2, maximum: 100 },
                                       format: { with: /\p{L}.*\p{L}/, allow_blank: true }
  end
end
