class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include ModelCleaners

  # Every enum validates its value, so an unknown one (e.g. from a form) is a
  # validation error instead of an ArgumentError. An enum can still pass its
  # own validate: option. Values given as keywords (enum :status, active: 0)
  # arrive in options, so they're separated first, as Rails' enum does.
  def self.enum(name, values = nil, **options)
    unless values
      values = options
      options = {}
    end
    super(name, values, **options.with_defaults(validate: true))
  end
end
