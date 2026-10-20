require "test_helper"

class RemovedAtFieldTest < ActiveSupport::TestCase
  test "form partial path resolves to readonly_date_time_field's form partial" do
    assert_equal "/madmin/fields/readonly_date_time_field/form", PersonResource.attributes[:removed_at].field.to_partial_path("form")
  end
end
