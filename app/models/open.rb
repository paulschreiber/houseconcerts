class Open < ApplicationRecord
  before_save :downcase_email
end
