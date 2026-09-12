class RSVPResource < Madmin::Resource
  # Attributes
  attribute :id
  attribute :full_name, field: LinkedStringField, label: "Name", form: false, index: true
  attribute :show_summary, field: ComputedField, label: "Show", form: false, show: false, index: true,
                           compute: ->(record) { record.show&.summary }
  attribute :uniqid, form: false, show: false, searchable: false
  attribute :first_name, searchable: true
  attribute :last_name, searchable: true
  attribute :email, searchable: true
  attribute :phone_number, searchable: true
  attribute :postcode, label: "Postal Code", searchable: false
  attribute :seats_reserved, label: "Seats", index: true
  attribute :seats_used
  attribute :ip_address, field: ReadonlyStringField, form: false, new: true, edit: true, searchable: false
  attribute :confirmed_at, field: ReadonlyDateTimeField, form: false, new: true, edit: true
  attribute :created_at
  attribute :updated_at
  attribute :referrer, field: ReadonlyStringField, form: false, new: true, edit: true, searchable: false
  attribute :response, field: HideableResponseField, index: true
  attribute :confirmed, field: RadioEnumField
  attribute :attended_before, field: HideableAttendedBeforeField, label: "Attended Before", form: false, show: false, index: true,
                              compute: ->(record) { record.attended_before? ? "✔" : "✖" }

  # Associations
  attribute :show

  # Add scopes to easily filter records
  scope :next_show
  scope :next_show_attendees
  scope :unconfirmed_rsvps
  scope :nonsubscribers
  scope :previous_show
  scope :previous_show_attendees

  # Add actions to the resource's show page
  # Pass collection: true to also render it in each row on the index page
  member_action(collection: true) do |record|
    if record.can_confirm?
      button_to "Confirm", confirm_madmin_rsvp_path(record), method: :patch, class: "btn btn-secondary"
    elsif record.can_waitlist?
      button_to "Waitlist", waitlist_madmin_rsvp_path(record), method: :patch, class: "btn btn-secondary"
    elsif Current.admin_scope == "next_show_attendees" && record.can_cancel?(@next_show)
      button_to "Cancel", cancel_madmin_rsvp_path(record), method: :patch, class: "btn btn-secondary"
    end
  end

  # Add actions to the resource's index page
  collection_action do
    next unless (totals = attendee_totals)

    tag.div class: "metrics" do
      tag.div(class: "metric") { tag.h4("Attendees") + tag.p(totals[:count]) } +
        tag.div(class: "metric") { tag.h4("Seats Reserved") + tag.p(totals[:seats_reserved]) }
    end
  end

  collection_action do
    next unless Current.admin_scope == "next_show_attendees"

    link_to "Print", print_madmin_rsvps_path, class: "btn btn-secondary", target: "_blank", rel: "noopener"
  end

  # Customize the display name of records in the admin area.
  def self.display_name(record) = "#{record.full_name} — #{record.show&.name} #{record.show&.start&.strftime('%Y-%m-%d')}"

  # Customize the default sort column and direction.
  # def self.default_sort_column = "created_at"
  #
  # def self.default_sort_direction = "desc"

  menu position: 40
end
