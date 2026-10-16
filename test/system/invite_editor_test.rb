require "application_system_test_case"

# The invite editor's preview updates as you type (invite_preview_controller.js),
# so it runs in a real browser.
class InviteEditorTest < ApplicationSystemTestCase
  setup do
    admins(:one).update!(password: "correct horse battery staple")
    visit new_admin_session_path
    fill_in "Email", with: admins(:one).email
    fill_in "Password", with: "correct horse battery staple"
    click_button "Log in"
    assert_no_current_path new_admin_session_path

    @show = shows(:upcoming)
    visit edit_madmin_show_invite_message_path(@show, @show.invite_message)
  end

  test "the preview shows the saved text, then unsaved edits as they're typed" do
    within_frame("invite-preview") { assert_text "Next up: a test show." }

    fill_in "Introduction", with: "A **new** intro. [Count me in][rsvp_yes]"

    within_frame("invite-preview") do
      assert_text "A new intro. Count me in"
      assert_selector "strong", text: "new"
      assert_selector "a[href='#rsvp_yes']", text: "Count me in"
    end
    assert_equal "Next up: a **test** show. [Count me in][rsvp_yes].", @show.invite_message.reload.intro
  end

  test "Send Test is disabled until edits are saved" do
    assert_button "Send Test", disabled: false

    fill_in "Introduction", with: "Unsaved"

    assert_button "Send Test", disabled: true
    click_button "Save"
    assert_text "Saved revision 1."
    assert_button "Send Test", disabled: false
  end
end
