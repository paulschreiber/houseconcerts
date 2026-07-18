require "test_helper"

class RsvpTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "fixture is valid" do
    assert rsvps(:one).valid?
  end

  test "requires a first and last name" do
    rsvp = RSVP.new(rsvps(:one).attributes.except("id").merge("first_name" => "", "last_name" => ""))
    assert_not rsvp.valid?
    assert_includes rsvp.errors.attribute_names, :first_name
    assert_includes rsvp.errors.attribute_names, :last_name
  end

  test "requires a valid email" do
    rsvp = RSVP.new(rsvps(:one).attributes.except("id").merge("email" => "not-an-email"))
    assert_not rsvp.valid?
    assert_includes rsvp.errors.attribute_names, :email
  end

  test "yes? and no? reflect the response attribute" do
    rsvp = RSVP.new(response: "yes")
    assert rsvp.yes?
    assert_not rsvp.no?

    rsvp.response = "no"
    assert rsvp.no?
    assert_not rsvp.yes?
  end

  test "unconfirmed? is true when confirmed is nil, blank, or 'no'" do
    rsvp = RSVP.new
    assert rsvp.unconfirmed?

    rsvp.confirmed = ""
    assert rsvp.unconfirmed?

    rsvp.confirmed = "no"
    assert rsvp.unconfirmed?

    rsvp.confirmed = "yes"
    assert_not rsvp.unconfirmed?
  end

  test "clear_seats_if_no zeroes out seats and confirmation when response is no" do
    rsvp = rsvps(:one)
    rsvp.response = "no"
    rsvp.save!

    assert_equal 0, rsvp.seats_reserved
    assert_nil rsvp.confirmed
  end

  test "update_confirmation_date sets confirmed_at when confirmed becomes yes" do
    rsvp = rsvps(:one)
    rsvp.update!(confirmed: nil)
    assert_nil rsvp.confirmed_at

    rsvp.update!(confirmed: "yes")
    assert_not_nil rsvp.confirmed_at
  end

  test "confirm! sets confirmed to yes only for a yes rsvp" do
    yes_rsvp = rsvps(:one)
    assert yes_rsvp.confirm!
    assert_equal "yes", yes_rsvp.reload.confirmed

    no_rsvp = rsvps(:one).dup
    no_rsvp.response = "no"
    assert_not no_rsvp.confirm!
  end

  test "waitlist! sets confirmed to waitlisted only for a yes rsvp" do
    rsvp = rsvps(:one)
    assert rsvp.waitlist!
    assert_equal "waitlisted", rsvp.reload.confirmed
  end

  test "notify_admin delivers a mailer email when a yes rsvp is created" do
    assert_emails 1 do
      RSVP.create!(
        first_name: "Notify",
        last_name: "Test",
        email: "notify.test@example.com",
        show_id: shows(:upcoming).id,
        response: "yes",
        seats_reserved: 1
      )
    end
  end

  test "person_exists? and create_person" do
    rsvp = RSVP.new(first_name: "New", last_name: "Person", email: "brand.new.person@example.com", show: shows(:upcoming))
    assert_not rsvp.person_exists?

    assert_difference("Person.count", 1) do
      rsvp.create_person
    end
    assert rsvp.person_exists?
  end
end
