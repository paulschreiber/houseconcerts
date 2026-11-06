require "test_helper"

class FormErrorTest < ActionView::TestCase
  test "lists each of a field's errors after it, each once, and no other field's" do
    rsvp = RSVP.new
    rsvp.errors.add(:email, "is blank")
    rsvp.errors.add(:email, "is invalid")
    rsvp.errors.add(:email, "is invalid")
    rsvp.errors.add(:name, "is too long")

    @rendered = form_with(model: rsvp, url: "/") do |f|
      f.label(:email) + f.email_field(:email) + f.text_field(:first_name) + f.radio_button(:email, "x") +
        f.text_field(:email, data: { inline_errors: false })
    end

    assert_select "label", 1
    assert_select ".field_with_errors label", false
    assert_select "span.field_with_errors:has(input[type=email]) + p.error", text: "is blank"
    assert_select "span.field_with_errors:has(input[type=email]) + p.error + p.error", text: "is invalid"
    assert_select "span.field_with_errors input[name='rsvp[first_name]']", false
    assert_select "span.field_with_errors input[type=radio]"
    assert_select "span.field_with_errors input[type=text][data-inline-errors=false]"
    assert_select "p.error", 2
  end

  test "the form errors summary lists only errors that no field shows" do
    rsvp = RSVP.new
    rsvp.errors.add(:email, "Enter your email address")
    rsvp.errors.add(:first_name, "Enter your first name")
    rsvp.errors.add(:show, "Enter your email address")

    @rendered = form_with(model: rsvp, url: "/") do |f|
      render(layout: "madmin/application/form_errors", locals: { record: rsvp }) do
        f.email_field(:email) + f.text_field(:first_name, data: { inline_errors: false })
      end
    end

    assert_select ".form-errors + span.field_with_errors input[type=email]"
    assert_select ".form-errors", text: /\APlease correct the following errors:/
    assert_select ".form-errors li", 2
    assert_select ".form-errors li", text: "Enter your first name"
    assert_select ".form-errors li", text: "Enter your email address"
    assert_select "p.error", text: "Enter your email address"
  end
end
