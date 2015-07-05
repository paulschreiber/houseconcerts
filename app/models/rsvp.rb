class Rsvp < ActiveRecord::Base
  belongs_to :show

  before_save :downcase_email
  before_save :update_confirmation_status
end
