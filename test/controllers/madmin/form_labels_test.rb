require "test_helper"

module Madmin
  class FormLabelsTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    [ Artist, Show, Venue, Person, RSVP, VenueGroup ].each do |model|
      test "every label on the #{model.name} edit and new forms names an element on the page" do
        [ send("edit_madmin_#{model.model_name.singular_route_key}_path", model.first),
          send("new_madmin_#{model.model_name.singular_route_key}_path") ].each do |path|
          get path
          assert_response :success

          ids = css_select("[id]").map { _1["id"] }
          unmatched = css_select("label[for]").map { _1["for"] }.reject { ids.include?(_1) }

          assert_empty unmatched, "#{path}: labels for missing ids"
        end
      end
    end

    test "a read-only field's label has no for" do
      get edit_madmin_artist_path(artists(:one))

      assert_select "label[for]", text: "Slug", count: 0
      assert_select "label", text: "Slug"
    end

    test "an association's label names its select" do
      get edit_madmin_show_path(Show.first)

      assert_select "label[for=show_venue_id]"
      assert_select "select#show_venue_id"
    end

    test "a radio group is named by its label" do
      get edit_madmin_show_path(Show.first)

      assert_select "label#show_status_label", text: "Status"
      assert_select "[role=radiogroup][aria-labelledby=show_status_label] input[name='show[status]']"
    end
  end
end
