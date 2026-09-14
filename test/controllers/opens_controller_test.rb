require "test_helper"

class OpensControllerTest < ActionDispatch::IntegrationTest
  test "records an open when a known uniqid, kind, and tag are given" do
    person = people(:one)

    assert_difference("Open.count", 1) do
      get open_tracking_path(tag: "test-show:invite", uniqid: person.uniqid, kind: "person")
    end

    open = Open.last
    assert_equal person.email, open.email
    assert_equal "test-show:invite", open.tag
    assert open.open
  end

  test "records an open when a known RSVP uniqid, kind, and tag are given" do
    rsvp = rsvps(:one)

    assert_difference("Open.count", 1) do
      get open_tracking_path(tag: "test-show:confirm", uniqid: rsvp.uniqid, kind: "rsvp")
    end

    open = Open.last
    assert_equal rsvp.email, open.email
    assert_equal "test-show:confirm", open.tag
    assert open.open
  end

  test "uses the kind hint to disambiguate a uniqid that collides across tables" do
    rsvp = rsvps(:one)
    rsvp.update_column(:uniqid, people(:one).uniqid) # rubocop:disable Rails/SkipsModelValidations

    get open_tracking_path(tag: "test-show:confirm", uniqid: people(:one).uniqid, kind: "rsvp")

    assert_equal rsvp.email, Open.last.email
  end

  test "falls back to a Person-then-RSVP lookup when no kind is given" do
    rsvp = rsvps(:one)
    rsvp.update_column(:uniqid, people(:one).uniqid) # rubocop:disable Rails/SkipsModelValidations

    get open_tracking_path(tag: "test-show:invite", uniqid: people(:one).uniqid)

    assert_equal people(:one).email, Open.last.email
  end

  test "does not record an open for an unknown uniqid" do
    assert_no_difference("Open.count") do
      get open_tracking_path(tag: "test-show:invite", uniqid: "nonexistent")
    end

    assert_response :success
  end

  test "always returns a blank gif" do
    get open_tracking_path(tag: "test-show:invite", uniqid: "nonexistent")

    assert_response :success
    assert_equal "image/gif", @response.media_type
  end
end
