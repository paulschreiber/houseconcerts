require "application_system_test_case"

# The batch buttons on a Madmin show page ask for confirmation through Turbo
# (which also disables a button while its request is in flight). These run in
# a real browser to check the confirmation is honored either way.
class MadminBatchButtonsTest < ApplicationSystemTestCase
  setup do
    admins(:one).update!(password: "correct horse battery staple")
    visit new_admin_session_path
    fill_in "Email", with: admins(:one).email
    fill_in "Password", with: "correct horse battery staple"
    click_button "Log in"
    assert_no_current_path new_admin_session_path

    visit madmin_show_path(shows(:upcoming))
  end

  test "accepting the confirmation starts the batch" do
    accept_confirm { click_button "Send Invites" }

    assert_text "Started sending invites for #{shows(:upcoming).name}."
    assert_equal 1, shows(:upcoming).batch_runs.invite.count
  end

  test "dismissing the confirmation leaves the button enabled and sends nothing" do
    message = dismiss_confirm { click_button "Send Invites" }

    assert_includes message, "Send invites for #{shows(:upcoming).name}?"
    assert_button "Send Invites", disabled: false
    assert_equal 0, shows(:upcoming).batch_runs.count
  end
end
