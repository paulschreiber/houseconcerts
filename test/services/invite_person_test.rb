require "test_helper"

class InvitePersonTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "delivers an invite email for an active person" do
    person = people(:one)

    assert_emails 1 do
      InvitePerson.call(person, shows(:upcoming))
    end
  end

  test "enqueues the invite by default" do
    assert_enqueued_emails 1 do
      InvitePerson.call(people(:one), shows(:upcoming))
    end
  end

  test "sends the invite immediately with deliver_now" do
    assert_no_enqueued_emails do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        InvitePerson.call(people(:one), shows(:upcoming), deliver_now: true)
      end
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

    result = nil
    with_stubbed(InvitesMailer, :with, ->(*_args) { raise "simulated enqueue failure" }) do
      assert_no_emails { result = InvitePerson.call(person, shows(:upcoming)) }
    end

    assert_not result
  end
end
