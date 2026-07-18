require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert people(:one).valid?
  end

  test "requires a first and last name" do
    person = Person.new(people(:one).attributes.except("id").merge("first_name" => "", "last_name" => ""))
    assert_not person.valid?
    assert_includes person.errors.attribute_names, :first_name
    assert_includes person.errors.attribute_names, :last_name
  end

  test "requires a valid email" do
    person = Person.new(people(:one).attributes.except("id").merge("email" => "not-an-email"))
    assert_not person.valid?
    assert_includes person.errors.attribute_names, :email
  end

  test "status predicate methods reflect the status attribute" do
    person = Person.new(status: "active")
    assert person.active?
    assert_not person.removed?

    person.status = "removed"
    assert person.removed?
    assert_not person.active?
  end

  test "ensure_venue_group adds the default venue group when a person has none" do
    person = Person.create!(first_name: "New", last_name: "Person", email: "venue.group.test@example.com")
    assert_equal [ venue_groups(:two) ], person.venue_groups
  end

  test "update_removal_status sets removed_at when status becomes removed" do
    person = people(:one)
    assert_nil person.removed_at

    person.update!(status: "removed")
    assert_not_nil person.removed_at
  end

  test "status bang methods update the status and fire callbacks" do
    person = people(:one)
    assert person.removed!
    assert_equal "removed", person.reload.status
    assert_not_nil person.removed_at
  end

  test "email is downcased before save" do
    person = Person.create!(first_name: "Mixed", last_name: "Case", email: "Mixed.Case@Example.COM")
    assert_equal "mixed.case@example.com", person.email
  end
end
