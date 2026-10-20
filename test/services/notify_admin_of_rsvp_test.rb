require "test_helper"

class NotifyAdminOfRSVPTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "a new yes rsvp notifies with type new" do
    assert_enqueued_email_with NotifyMailer, :rsvp, args: ->(args) { args[1] == "new" } do
      RSVP.create!(show: shows(:upcoming), email: "new-yes@example.com", first_name: "New", last_name: "Yes", response: "yes", seats_reserved: 1)
    end
  end

  test "a yes changed to no notifies with type cancel" do
    assert_enqueued_email_with NotifyMailer, :rsvp, args: ->(args) { args[1] == "cancel" } do
      rsvps(:one).update!(response: "no")
    end
  end
end
