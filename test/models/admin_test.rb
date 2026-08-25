require "test_helper"

class AdminTest < ActiveSupport::TestCase
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
end
