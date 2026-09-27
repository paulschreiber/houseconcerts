require "application_system_test_case"

class AdminLoginDisableOnSubmitTest < ApplicationSystemTestCase
  test "disables the login button once clicked, preventing a second submission from erroring" do
    visit new_admin_session_path

    # webauthn-get sets its own display style once its JS has loaded and
    # initialized; wait for that before interacting so a slow-to-load
    # bundle (as can happen on a cold CI cache) doesn't beat our click.
    assert_selector "webauthn-get[style]"

    # Block the real submission so the button's disabled state doesn't
    # race a full server round trip / page reload.
    page.execute_script(<<~JS)
      document.querySelector("form.new_admin").addEventListener("submit", (e) => e.preventDefault())
    JS

    fill_in "Email", with: "not-a-real-admin@example.com"
    fill_in "Password", with: "wrong password"
    click_button "Log in"

    assert_selector "input[type=submit][value='Log in']:disabled"
  end
end
