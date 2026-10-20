require "test_helper"

# The controller tests check the scopes of the Attended Before, Opened and
# Date Modified columns.
class IndexScopesTest < ActiveSupport::TestCase
  teardown { Current.admin_scope = nil }

  def assert_index_scopes(field, shown:, hidden:)
    shown.each do |scope|
      Current.admin_scope = scope
      assert field.visible?(:index), "expected #{field.attribute_name} on the index for scope=#{scope.inspect}"
    end
    hidden.each do |scope|
      Current.admin_scope = scope
      assert_not field.visible?(:index), "expected #{field.attribute_name} hidden on the index for scope=#{scope.inspect}"
    end
  end

  test "Response shows on every RSVP list but the attendee and unconfirmed ones" do
    assert_index_scopes RSVPResource.attributes[:response].field,
                        shown: [ nil, "next_show", "nonsubscribers", "previous_show" ],
                        hidden: %w[next_show_attendees previous_show_attendees unconfirmed_rsvps]
  end

  test "Removed At shows only on the removed people list" do
    assert_index_scopes PersonResource.attributes[:removed_at].field, shown: %w[removed], hidden: [ nil, "active" ]
  end

  test "a column without index_scopes shows on every scope" do
    assert_index_scopes RSVPResource.attributes[:seats_reserved].field, shown: [ nil, "next_show_attendees" ], hidden: []
  end

  test "index_scopes doesn't affect the show page or the form" do
    Current.admin_scope = "next_show_attendees"
    response = RSVPResource.attributes[:response].field

    assert response.visible?(:show)
    assert response.visible?(:form)
  end
end
