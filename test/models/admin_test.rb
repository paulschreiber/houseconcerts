require "test_helper"

class AdminTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "requires a validly formatted email" do
    admin = Admin.new(email: "not-an-email", password: "a-good-password")

    assert_not admin.valid?
    assert_includes admin.errors[:email], "is invalid"
  end

  test "requires a unique email" do
    admin = Admin.new(email: admins(:one).email, password: "a-good-password")

    assert_not admin.valid?
    assert_includes admin.errors[:email], "has already been taken"
  end

  test "requires a password of at least 8 characters" do
    admin = Admin.new(email: "new-admin@example.com", password: "short")

    assert_not admin.valid?
    assert_includes admin.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "sends password reset instructions from the site's confirms address" do
    assert_emails 1 do
      admins(:one).send_reset_password_instructions
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ "#{Settings.confirms_from_email}@#{Settings.domain}" ], email.from
    assert_equal Settings.confirms_from_name, email[:from].display_names.first
  end
end
