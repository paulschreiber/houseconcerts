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

  test "returns false instead of raising when enqueueing the invite fails" do
    person = people(:one)

    original_invite = InvitesMailer.method(:invite)
    InvitesMailer.define_singleton_method(:invite) { |*_args| raise "simulated enqueue failure" }

    result = nil
    begin
      assert_no_emails { result = InvitePerson.call(person, shows(:upcoming)) }
    ensure
      InvitesMailer.define_singleton_method(:invite, original_invite)
    end

    assert_not result
  end
end
