require "application_system_test_case"

class AdminLoginDisableOnSubmitTest < ApplicationSystemTestCase
  test "disables the login button once clicked, preventing a second submission from erroring" do
    visit new_admin_session_path

    fill_in "Email", with: "not-a-real-admin@example.com"
    fill_in "Password", with: "wrong password"
    click_button "Log in"

    assert_selector "input[type=submit][value='Log in']:disabled"
  end
end
