require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert people(:one).valid?
  end

  test "rejects values longer than the form allows" do
    { first_name: 100, last_name: 100, postcode: 10 }.each do |attribute, maximum|
      record = people(:one)
      record[attribute] = "A" * (maximum + 1)

      assert_not record.valid?, "#{attribute} should be invalid"
      assert_includes record.errors[attribute], "is too long (maximum is #{maximum} characters)"
    end
  end

  test "rejects an email longer than 200 characters" do
    record = people(:one)
    record.email = "#{'a' * 189}@example.com"

    assert_not record.valid?
    assert_includes record.errors[:email], "is too long (maximum is 200 characters)"
  end

  test "rejects a phone number longer than 30 characters once formatted" do
    record = people(:one)
    record.phone_number = "2125551234 ext 1234567890123"

    assert_not record.valid?
    assert_includes record.errors[:phone_number], "is too long (maximum is 30 characters)"
  end

  test "accepts a phone number with an extension that the form allows" do
    record = people(:one)
    record.phone_number = "212-555-1234 x12345"

    assert record.valid?, record.errors.full_messages.to_sentence
    assert_equal "(212) 555-1234 x12345", record.phone_number
  end

  test "accepts names at the maximum length" do
    record = people(:one)
    record.first_name = "A#{'a' * 99}"
    record.last_name = "B#{'b' * 99}"

    assert record.valid?, record.errors.full_messages.to_sentence
  end

  test "email_address_with_name formats the name and email as one address" do
    person = Person.new(first_name: "Jane", last_name: "Smith", email: "jane@example.com")

    assert_equal "Jane Smith <jane@example.com>", person.email_address_with_name
  end

  test "email_address_with_name is just the email when there's no name" do
    person = Person.new(email: "noname@example.com")

    assert_equal "noname@example.com", person.email_address_with_name
  end

  test "email_address_with_name quotes names so they can't add recipients" do
    person = Person.new(first_name: 'Bob", attacker@evil.com, "X', last_name: "Y", email: "bob@example.com")

    addresses = Mail::AddressList.new(person.email_address_with_name).addresses
    assert_equal [ "bob@example.com" ], addresses.map(&:address)
    assert_equal 'Bob", attacker@evil.com, "X Y', addresses.first.display_name
  end

  test "defaults uniqid to a 16-character random token" do
    person = Person.create!(first_name: "New", last_name: "Person", email: "new-uniqid@example.com")

    assert_equal 16, person.uniqid.length
  end

  test "requires a first and last name" do
    person = Person.new(people(:one).attributes.except("id").merge("first_name" => "", "last_name" => ""))
    assert_not person.valid?
    assert_includes person.errors.attribute_names, :first_name
    assert_includes person.errors.attribute_names, :last_name
  end

  test "requires a valid email" do
    person = Person.new(people(:one).attributes.except("id").merge("email" => "not-an-email"))
    assert_not person.valid?
    assert_includes person.errors.attribute_names, :email
  end

  test "status predicate methods reflect the status attribute" do
    person = Person.new(status: "active")
    assert person.active?
    assert_not person.removed?

    person.status = "removed"
    assert person.removed?
    assert_not person.active?
  end

  test "ensure_venue_group adds the default venue group when a person has none" do
    person = Person.create!(first_name: "New", last_name: "Person", email: "venue.group.test@example.com")
    assert_equal [ venue_groups(:two) ], person.venue_groups
  end

  test "update_removal_status sets removed_at when status becomes removed" do
    person = people(:one)
    assert_nil person.removed_at

    person.update!(status: "removed")
    assert_not_nil person.removed_at
  end

  test "status bang methods update the status and fire callbacks" do
    person = people(:one)
    assert person.removed!
    assert_equal "removed", person.reload.status
    assert_not_nil person.removed_at
  end

  test "email is downcased before save" do
    person = Person.create!(first_name: "Mixed", last_name: "Case", email: "Mixed.Case@Example.COM")
    assert_equal "mixed.case@example.com", person.email
  end

  test "can_invite? is true only for an active person" do
    person = Person.new(status: "active")
    assert person.can_invite?

    %w[bouncing moved removed].each do |status|
      person.status = status
      assert_not person.can_invite?, "can_invite? wrong for status=#{status}"
    end
  end

  test "can_rsvp_no? is true for an active person who hasn't RSVPd for the next show" do
    person = people(:one)
    assert person.can_rsvp_no?
  end

  test "can_rsvp_no? is false for an inactive person" do
    person = people(:one)
    person.update!(status: "removed")
    assert_not person.can_rsvp_no?
  end

  test "can_rsvp_no? is false once the person has an RSVP for the next show" do
    person = people(:one)
    RSVP.create!(first_name: person.first_name, last_name: person.last_name, email: person.email,
                 show: Show.next, response: "yes", seats_reserved: 2)

    assert_not person.can_rsvp_no?
  end

  test "can_rsvp_no? uses Current.next_show_rsvpd_emails when set, without querying" do
    person = people(:one)
    Current.next_show_rsvpd_emails = Set.new

    assert_no_queries { assert person.can_rsvp_no? }
  ensure
    Current.next_show_rsvpd_emails = nil
  end

  test "can_rsvp_no? is false when the preloaded set includes the person's email" do
    person = people(:one)
    Current.next_show_rsvpd_emails = Set[person.email]

    assert_not person.can_rsvp_no?
  ensure
    Current.next_show_rsvpd_emails = nil
  end

  # The messages are full sentences shown under each field, so full_messages
  # (e.g. in Madmin) uses them as written, without the attribute name in front.
  test "full_messages use the messages as written" do
    record = Person.new(first_name: "JANE", last_name: "doe", email: "not-an-email")
    record.valid?

    assert_includes record.errors.full_messages, "Your first name cannot be in all caps"
    assert_includes record.errors.full_messages, "Your last name cannot be in all lowercase"
    assert_includes record.errors.full_messages, "Enter your email address"
  end

  test "a too-short first name asks for the first name" do
    record = Person.new(first_name: "J", last_name: "doe", email: "not-an-email")
    record.valid?

    assert_includes record.errors.full_messages, "Enter your first name"
  end
end
