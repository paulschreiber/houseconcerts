class Open < ApplicationRecord
  normalizes :email, with: ContactDetails::NORMALIZE_EMAIL

  # Tags are "<show slug>:<email type>", e.g. "2026-11-19:confirm".
  def self.tag_for(show, email_type)
    "#{show.slug}:#{email_type}"
  end

  scope :invite, -> { where(arel_table[:tag].matches("%:invite")) }
  scope :confirm, -> { where(arel_table[:tag].matches("%:confirm")) }
  scope :remind, -> { where(arel_table[:tag].matches("%:remind")) }
  # Opens of any invite to the show, unopened-recipient resends included.
  scope :invites_to, ->(show) { where(arel_table[:tag].matches("#{sanitize_sql_like(show.slug)}:invite%")) }

  # The [tag, email] pairs of the given RSVPs' opened confirmation emails, so
  # a caller with many RSVPs to check (e.g. rendering a page of the admin
  # index) can look each one up against a single query.
  def self.confirmations_opened(rsvps)
    where(tag: rsvps.map { |rsvp| tag_for(rsvp.show, "confirm") }.uniq, email: rsvps.map(&:email).uniq).pluck(:tag, :email).to_set
  end
end
