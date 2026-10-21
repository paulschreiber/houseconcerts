class Current < ActiveSupport::CurrentAttributes
  attribute :ip_address
  attribute :admin_scope
  attribute :admin_action
  attribute :attended_rsvp_ids_by_email
  attribute :confirm_opens
  attribute :next_show_rsvpd_emails
  attribute :mailer_claim
  attribute :locked_invite_message_ids
end
