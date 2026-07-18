require "application_system_test_case"

class MailingListTest < ApplicationSystemTestCase
  test "pasting a name splits it into first name, last name, and email" do
    visit mailing_list_path

    field = find(:css, "input[data-name-paste-target='firstName']")
    script = <<~JS
      const field = arguments[0];
      const dataTransfer = new DataTransfer();
      dataTransfer.setData('text', arguments[1]);
      const event = new ClipboardEvent('paste', { clipboardData: dataTransfer, bubbles: true, cancelable: true });
      field.dispatchEvent(event);
    JS
    page.execute_script(script, field.native, "Jane Doe <jane@example.com>")

    assert_equal "Jane", find(:css, "input[data-name-paste-target='firstName']").value
    assert_equal "Doe", find(:css, "input[data-name-paste-target='lastName']").value
    assert_equal "jane@example.com", find(:css, "input[data-name-paste-target='email']").value
  end

  test "signing up joins the mailing list and redirects to the thanks page" do
    visit mailing_list_path

    fill_in "person_first_name", with: "Jane"
    fill_in "person_last_name", with: "Doe"
    fill_in "person_email", with: "jane-system-test@example.com"
    click_button "Join Mailing List"

    assert_text "Jane"
    assert Person.exists?(email: "jane-system-test@example.com")
  end
end
