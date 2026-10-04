class Open < ApplicationRecord
  before_save :downcase_email

  # Tags are "<show slug>:<email type>" (see InvitesMailer).
  scope :invite, -> { where(arel_table[:tag].matches("%:invite")) }
  scope :confirm, -> { where(arel_table[:tag].matches("%:confirm")) }
  scope :remind, -> { where(arel_table[:tag].matches("%:remind")) }
end
