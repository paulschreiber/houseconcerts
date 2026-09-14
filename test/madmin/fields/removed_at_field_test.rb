require "test_helper"

class RemovedAtFieldTest < ActiveSupport::TestCase
  teardown { Current.admin_scope = nil }

  def build_field
    PersonResource.attributes[:removed_at].field
  end

  test "hidden on index outside the removed scope" do
    field = build_field

    [ nil, "active", "subscribed" ].each do |scope|
      Current.admin_scope = scope
      assert_not field.visible?(:index), "expected removed_at to be hidden for scope=#{scope.inspect}"
    end
  end

  test "visible on index for the removed scope" do
    field = build_field
    Current.admin_scope = "removed"

    assert field.visible?(:index)
  end

  test "visible on show regardless of scope" do
    field = build_field
    Current.admin_scope = nil

    assert field.visible?(:show)
  end

  test "form partial path resolves to readonly_date_time_field's form partial" do
    assert_equal "/madmin/fields/readonly_date_time_field/form", build_field.to_partial_path("form")
  end
end
