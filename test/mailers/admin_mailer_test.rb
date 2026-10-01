require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  test "passkey_added tells the admin which passkey was added, from where, and what to do" do
    email = AdminMailer.passkey_added(admins(:one), "Laptop", "203.0.113.7")

    assert_equal [ admins(:one).email ], email.to
    assert_equal "A passkey was added to your #{Settings.site_name} admin account", email.subject
    assert_includes email.body.encoded, "Laptop"
    assert_includes email.body.encoded, "203.0.113.7"
    assert_includes email.body.encoded, "/#{Settings.admin_prefix}/passkeys/new"
  end

  test "passkey_removed tells the admin which passkey was removed" do
    email = AdminMailer.passkey_removed(admins(:one), "Old Phone", "203.0.113.7")

    assert_equal [ admins(:one).email ], email.to
    assert_equal "A passkey was removed from your #{Settings.site_name} admin account", email.subject
    assert_includes email.body.encoded, "Old Phone"
  end
end
