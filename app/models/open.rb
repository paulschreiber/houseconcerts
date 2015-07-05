class Open < ActiveRecord::Base
  before_save :downcase_email
end
