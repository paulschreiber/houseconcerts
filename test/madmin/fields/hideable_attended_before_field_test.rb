require "test_helper"

class HideableAttendedBeforeFieldTest < ActiveSupport::TestCase
  teardown { Current.admin_scope = nil }

  def build_field
    RSVPResource.attributes[:attended_before].field
  end

  test "hidden on index for no scope, previous_show, and previous_show_attendees scopes" do
    field = build_field

    [ nil, "previous_show", "previous_show_attendees" ].each do |scope|
      Current.admin_scope = scope
      assert_not field.visible?(:index), "expected attended_before to be hidden for scope=#{scope.inspect}"
    end
  end

  test "visible on index for other scopes" do
    field = build_field
    Current.admin_scope = "next_show_attendees"

    assert field.visible?(:index)
  end

  test "index partial path resolves to computed_field's index partial" do
    assert_equal "/madmin/fields/computed_field/index", build_field.to_partial_path("index")
  end
end
