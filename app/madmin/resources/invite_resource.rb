# Every show's invite revisions. Revisions are written and viewed per show
# (InviteMessagesController), so this is only the list: View and Edit link
# to the revision's pages there.
class InviteResource < Madmin::Resource
  model InviteMessage

  attribute :show_dated_name, field: ComputedField, label: "Show", index: true, link: true,
                              compute: ->(record) { record.show.dated_name }
  attribute :revision, index: true
  attribute :status, field: ComputedField, index: true,
                     compute: ->(record) { InviteMessage.status_label(InviteResource.locked?(record)) }
  attribute :updated_at, field: ShortDateTimeField, label: "Saved", index: true

  # Edit, beside View, until the revision is sent, as on Invite History.
  # (Madmin's own Edit needs the resource editable, which would also add New,
  # and a revision can only be started from its show.)
  member_action(collection: true) do |record|
    render "madmin/invite_messages/edit_button", invite_message: record, locked: InviteResource.locked?(record)
  end

  def self.readonly?
    true
  end

  # From the page's preloaded ids (see Madmin::InvitesController).
  def self.locked?(record)
    ids = Current.locked_invite_message_ids
    ids ? ids.include?(record.id) : record.locked?
  end

  def self.show_path(record)
    Rails.application.routes.url_helpers.madmin_show_invite_message_path(record.show, record)
  end

  def self.default_sort_column
    "updated_at"
  end

  def self.default_sort_direction
    "desc"
  end

  menu position: 22
end
