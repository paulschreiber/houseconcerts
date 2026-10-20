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

  test "changing the email of an admin who hasn't signed in sends a new link to the new address" do
    admin = admins(:two)

    assert_enqueued_email_with AdminMailer, :welcome, args: ->(args) { args.first.email == "jane.smith@example.com" } do
      admin.update!(email: "jane.smith@example.com")
    end

    assert_predicate admin.reload.reset_password_token, :present?
  end

  test "changing the email tells the old address" do
    admin = admins(:two)
    old_email = admin.email

    perform_enqueued_jobs do
      admin.update!(email: "jane.smith@example.com")
    end

    email = ActionMailer::Base.deliveries.find { |mail| mail.to == [ old_email ] }
    assert_equal "Your admin email address was changed", email.subject
    assert_includes email.body.encoded, "jane.smith@example.com"
  end

  test "changing the email of an admin who has signed in sends no new password link" do
    admin = admins(:two)
    admin.update!(sign_in_count: 3)

    admin.update!(email: "jane.smith@example.com")

    assert_not(enqueued_jobs.any? { |job| job["arguments"].first(2) == %w[AdminMailer welcome] })
  end

  test "an update that doesn't change the email sends nothing" do
    assert_no_enqueued_emails do
      admins(:two).update!(sign_in_count: 1)
    end
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
