require "test_helper"

class InvitePersonTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "delivers an invite email for an active person" do
    person = people(:one)

    assert_emails 1 do
      InvitePerson.call(person, shows(:upcoming))
    end
  end

  test "does not deliver an email for an inactive person" do
    person = people(:one)
    person.update!(status: "removed")

    assert_no_emails do
      InvitePerson.call(person, shows(:upcoming))
    end
  end
end
