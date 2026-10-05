require "test_helper"

class AddPhoneNumbersTest < ActiveSupport::TestCase
  test "fills in a missing phone number from the person's latest RSVP that has one" do
    rsvp(shows(:past), "2125550001")
    rsvp(shows(:upcoming), "2125550002")
    person = Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")

    assert_equal [ person ], AddPhoneNumbers.call
    assert_equal RSVP.order(:id).last.phone_number, person.reload.phone_number
  end

  test "with a show, uses only that show's RSVPs" do
    rsvp(shows(:upcoming), "2125550002")
    person = Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")

    assert_empty AddPhoneNumbers.call(shows(:past))
    assert_nil person.reload.phone_number

    assert_equal [ person ], AddPhoneNumbers.call(shows(:upcoming))
  end

  test "people are those missing a phone number that an RSVP has, without changing them" do
    rsvp(shows(:past), "2125550001")
    person = Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")

    assert_equal [ person ], AddPhoneNumbers.new(shows(:past)).people.to_a
    assert_empty AddPhoneNumbers.new(shows(:upcoming)).people
    assert_nil person.reload.phone_number
  end

  test "leaves an existing phone number alone" do
    rsvp(shows(:past), "2125550001")
    person = Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com", phone_number: "2125559999")

    assert_empty AddPhoneNumbers.call
    assert_equal "2125559999", person.reload.phone_number.gsub(/\D/, "").last(10)
  end

  test "fills in a phone number saved as blank" do
    rsvp(shows(:past), "2125550001")
    person = Person.create!(first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com")
    person.update_column(:phone_number, "") # rubocop:disable Rails/SkipsModelValidations

    assert_equal [ person ], AddPhoneNumbers.call
    assert_predicate person.reload.phone_number, :present?
  end

  test "looks up the RSVPs in one query, however many people it updates" do
    %w[Amy Bob Cal].each_with_index do |first_name, i|
      email = "#{first_name.downcase}@example.com"
      RSVP.create!(show: shows(:past), first_name:, last_name: "Smith", email:, response: "yes", seats_reserved: 1,
                   phone_number: "212555000#{i}")
      Person.create!(first_name:, last_name: "Smith", email:)
    end
    Person.where(last_name: "Smith").update_all(phone_number: nil) # rubocop:disable Rails/SkipsModelValidations

    rsvp_queries = 0
    counter = ->(*, payload) { rsvp_queries += 1 if payload[:sql].match?(/FROM [`"]rsvps[`"]/) }
    people = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { AddPhoneNumbers.call }

    assert_equal 3, people.size
    assert_equal 1, rsvp_queries
  end

  private

    def rsvp(show, phone_number)
      RSVP.create!(show:, first_name: "Jane", last_name: "Smith", email: "jane.smith@example.com",
                   response: "yes", seats_reserved: 1, phone_number:)
    end
end
