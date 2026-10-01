require "application_system_test_case"

# The batch buttons on a Madmin show page rely on the disable-on-submit
# Stimulus controller, which Madmin's own importmap only gets because
# config/initializers/madmin.rb pins it. These run in a real browser to check
# the controller actually loads there and behaves.
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

  test "a batch button is disabled once its submission starts" do
    # Simulate Turbo starting the submission (without sending anything) and
    # check the button the controller targets is now disabled.
    disabled = page.evaluate_script(<<~JS)
      (() => {
        const button = [...document.querySelectorAll("button")].find((b) => b.textContent.trim() === "Send Invites");
        button.form.dispatchEvent(new CustomEvent("turbo:submit-start", { bubbles: true }));
        return button.disabled;
      })()
    JS

    assert disabled, "Send Invites should be disabled once its submission starts"
  end

  test "dismissing the confirmation leaves the button enabled and sends nothing" do
    message = dismiss_confirm { click_button "Send Invites" }

    assert_includes message, "Send invites for #{shows(:upcoming).name}?"
    assert_button "Send Invites", disabled: false
    assert_equal 0, shows(:upcoming).batch_runs.count
  end
end
