require "test_helper"

class HideableResponseFieldTest < ActiveSupport::TestCase
  teardown { Current.admin_scope = nil }

  def build_field
    RSVPResource.attributes[:response].field
  end

  test "hidden on index for next_show_attendees, previous_show_attendees, and unconfirmed_rsvps scopes" do
    field = build_field

    %w[next_show_attendees previous_show_attendees unconfirmed_rsvps].each do |scope|
      Current.admin_scope = scope
      assert_not field.visible?(:index), "expected response to be hidden for scope=#{scope}"
    end
  end

  test "visible on index for other scopes" do
    field = build_field
    Current.admin_scope = "next_show"

    assert field.visible?(:index)
  end

  test "visible on show and form regardless of scope" do
    field = build_field
    Current.admin_scope = "next_show_attendees"

    assert field.visible?(:show)
    assert field.visible?(:form)
  end

  test "form partial path resolves to radio_enum_field's form partial" do
    assert_equal "/madmin/fields/radio_enum_field/form", build_field.to_partial_path("form")
  end
end
