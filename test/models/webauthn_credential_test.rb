require "test_helper"

class WebauthnCredentialTest < ActiveSupport::TestCase
  test "trims surrounding whitespace from the name" do
    assert_equal "Laptop", WebauthnCredential.new(name: "  Laptop\n").name
  end

  test "a whitespace-only name is blank" do
    credential = WebauthnCredential.new(name: "   ")

    assert_not credential.valid?
    assert_includes credential.errors[:name], "can't be blank"
  end
end
