require "test_helper"

class CustomPartialsTest < ActiveSupport::TestCase
  def partial_paths(field)
    CustomPartials::VIEWS.map { |view| field.to_partial_path(view) }
  end

  test "views a field names use its own partials, the rest the Madmin field type's" do
    assert_equal %w[/madmin/fields/string/index /madmin/fields/email_field/show /madmin/fields/string/form],
                 partial_paths(PersonResource.attributes[:email].field)
    assert_equal %w[/madmin/fields/text/index /madmin/fields/multiline_text_field/show /madmin/fields/text/form],
                 partial_paths(PersonResource.attributes[:notes].field)
  end

  test "a subclass keeps its parent's custom partials and can borrow another field's" do
    assert_equal %w[/madmin/fields/short_date_time_field/index /madmin/fields/date_time/show /madmin/fields/readonly_date_time_field/form],
                 partial_paths(PersonResource.attributes[:removed_at].field)
  end

  test "a field with no custom partials uses the Madmin field type's, except where it overrides" do
    assert_equal %w[/madmin/fields/linked_string_field/index /madmin/fields/string/show /madmin/fields/string/form],
                 partial_paths(InviteResource.attributes[:show_dated_name].field)
    assert_equal %w[/madmin/fields/string/index /madmin/fields/string/show /madmin/fields/string/form],
                 partial_paths(InviteResource.attributes[:status].field)
  end

  test "custom_partials rejects unknown views" do
    field = Class.new(Madmin::Fields::String) { include CustomPartials }

    assert_raises(ArgumentError) { field.custom_partials :froms }
  end
end
