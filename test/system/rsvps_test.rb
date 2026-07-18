require "application_system_test_case"

class RsvpsTest < ApplicationSystemTestCase
  test "pasting a name splits it into first name, last name, and email" do
    visit rsvp_for_show_path(slug: shows(:upcoming).slug)

    paste_name(first_name_field, "Jane Doe <jane@example.com>")

    assert_equal "Jane", first_name_field.value
    assert_equal "Doe", last_name_field.value
    assert_equal "jane@example.com", email_field.value
  end

  test "leaves the fields alone when the pasted text doesn't match the expected format" do
    visit rsvp_for_show_path(slug: shows(:upcoming).slug)

    paste_name(first_name_field, "not a name and email")

    assert_equal "", first_name_field.value
    assert_equal "", last_name_field.value
    assert_equal "", email_field.value
  end

  test "selecting a seat count selects yes" do
    visit rsvp_for_show_path(slug: shows(:upcoming).slug)

    seat_radio(2).click

    assert yes_radio.checked?
  end

  test "selecting no clears the selected seat count" do
    visit rsvp_for_show_path(slug: shows(:upcoming).slug)

    seat_radio(2).click
    assert seat_radio(2).checked?

    no_radio.click

    assert_not seat_radio(2).checked?
  end

  test "submitting the form reserves a seat and redirects to the thanks page" do
    visit rsvp_for_show_path(slug: shows(:upcoming).slug)

    fill_in "rsvp_first_name", with: "Jane"
    fill_in "rsvp_last_name", with: "Doe"
    fill_in "rsvp_email", with: "jane-system-test@example.com"
    seat_radio(2).click
    click_button "Reserve Seats"

    assert_text "Jane"
    assert_equal 1, RSVP.where(email: "jane-system-test@example.com").count
  end

  private

    def first_name_field
      find(:css, "input[data-name-paste-target='firstName']")
    end

    def last_name_field
      find(:css, "input[data-name-paste-target='lastName']")
    end

    def email_field
      find(:css, "input[data-name-paste-target='email']")
    end

    def seat_radio(count)
      find(:css, "input[data-seat-selection-target='seat'][value='#{count}']")
    end

    def yes_radio
      find(:css, "input[data-seat-selection-target='yes']")
    end

    def no_radio
      find(:css, "input[data-action='click->seat-selection#clearSeats']")
    end

    def paste_name(field, text)
      script = <<~JS
        const field = arguments[0];
        const dataTransfer = new DataTransfer();
        dataTransfer.setData('text', arguments[1]);
        const event = new ClipboardEvent('paste', { clipboardData: dataTransfer, bubbles: true, cancelable: true });
        field.dispatchEvent(event);
      JS
      page.execute_script(script, field.native, text)
    end
end
