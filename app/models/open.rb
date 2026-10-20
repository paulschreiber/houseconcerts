class Open < ApplicationRecord
  before_save :downcase_email

  # Tags are "<show slug>:<email type>", e.g. "2026-11-19:confirm".
  def self.tag_for(show, email_type) = "#{show.slug}:#{email_type}"

  scope :invite, -> { where(arel_table[:tag].matches("%:invite")) }
  scope :confirm, -> { where(arel_table[:tag].matches("%:confirm")) }
  scope :remind, -> { where(arel_table[:tag].matches("%:remind")) }
  # Opens of any invite to the show, unopened-recipient resends included.
  scope :invites_to, ->(show) { where(arel_table[:tag].matches("#{sanitize_sql_like(show.slug)}:invite%")) }
end
