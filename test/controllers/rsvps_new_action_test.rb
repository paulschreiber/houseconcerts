require "test_helper"

class RsvpsNewActionTest < ActionDispatch::IntegrationTest
  test "index redirects to new rsvp form" do
    get rsvps_path
    assert_redirected_to new_rsvp_path
  end

  test "new redirects home when slug is blank" do
    get new_rsvp_path
    assert_redirected_to root_url
  end

  test "new redirects home for a nonexistent show slug" do
    get rsvp_for_show_path(slug: "nonexistent-show")
    assert_redirected_to root_url
  end

  test "new redirects home for a show that already occurred" do
    get rsvp_for_show_path(slug: shows(:past).slug)
    assert_redirected_to root_url
  end

  test "new renders the form for an upcoming show" do
    get rsvp_for_show_path(slug: shows(:upcoming).slug)
    assert_response :success
    assert_select "form"
  end

  test "new prefills the form from a person's uniqid when no rsvp exists yet" do
    get modify_rsvp_path(slug: shows(:upcoming).slug, uniqid: people(:one).uniqid)
    assert_response :success
    assert_select "input[name='rsvp[first_name]'][value=?]", people(:one).first_name
    assert_select "input[name='rsvp[email]'][value=?]", people(:one).email
  end

  test "new prefills the form from an existing rsvp's uniqid" do
    get modify_rsvp_path(slug: shows(:upcoming).slug, uniqid: rsvps(:one).uniqid)
    assert_response :success
    assert_select "input[name='rsvp[first_name]'][value=?]", rsvps(:one).first_name
  end

  test "new does not display validation errors on a plain page load" do
    get rsvp_for_show_path(slug: shows(:upcoming).slug)
    assert_response :success
    assert_select ".error", count: 0
  end

  test "new does not display validation errors when prefilling from a person's uniqid" do
    get modify_rsvp_path(slug: shows(:upcoming).slug, uniqid: people(:one).uniqid)
    assert_response :success
    assert_select ".error", count: 0
  end

  test "new does not display validation errors when prefilling from an existing rsvp's uniqid" do
    get modify_rsvp_path(slug: shows(:upcoming).slug, uniqid: rsvps(:one).uniqid)
    assert_response :success
    assert_select ".error", count: 0
  end

  test "new renders a label for each seats_reserved radio option with a matching id" do
    get rsvp_for_show_path(slug: shows(:upcoming).slug)
    assert_response :success

    (Settings.show.min_seats..Settings.show.max_seats).each do |count|
      assert_select "input#rsvp_seats_reserved_#{count}[type=radio]"
      assert_select "label[for='rsvp_seats_reserved_#{count}']"
    end
  end

  test "new renders a label for each response radio option with a matching id" do
    get rsvp_for_show_path(slug: shows(:upcoming).slug)
    assert_response :success

    RSVP.responses.each_key do |response|
      assert_select "input#rsvp_response_#{response}[type=radio]"
      assert_select "label[for='rsvp_response_#{response}']"
    end
  end

  test "new with a 'no' response for a person with no existing rsvp saves and redirects to thanks" do
    assert_difference("RSVP.count", 1) do
      get rsvp_response_path(slug: shows(:upcoming).slug, uniqid: people(:one).uniqid, response: "no")
    end

    new_rsvp = RSVP.last
    assert_equal "no", new_rsvp.response
    assert_redirected_to rsvp_thanks_path(uniqid: new_rsvp.uniqid)
  end

  test "a 'no' link with another show's RSVP token doesn't move that RSVP" do
    past_rsvp = RSVP.create!(first_name: "Jo", last_name: "Guest", email: "jo.guest@example.com", show: shows(:past),
                             response: "yes", seats_reserved: 2)

    assert_difference("RSVP.count", 1) do
      get rsvp_response_path(slug: shows(:upcoming).slug, uniqid: past_rsvp.uniqid, response: "no")
    end

    past_rsvp.reload
    assert_equal shows(:past), past_rsvp.show
    assert_equal "yes", past_rsvp.response
    assert_equal 2, past_rsvp.seats_reserved

    new_rsvp = RSVP.find_by!(email: past_rsvp.email, show: shows(:upcoming))
    assert_equal "no", new_rsvp.response
    assert_redirected_to rsvp_thanks_path(uniqid: new_rsvp.uniqid)
  end

  test "another show's RSVP token prefills a new RSVP for this show" do
    past_rsvp = RSVP.create!(first_name: "Jo", last_name: "Guest", email: "jo.guest@example.com", show: shows(:past),
                             response: "yes", seats_reserved: 2)

    assert_no_difference("RSVP.count") do
      get modify_rsvp_path(slug: shows(:upcoming).slug, uniqid: past_rsvp.uniqid)
    end

    assert_response :success
    assert_select "input[name='rsvp[email]'][value='jo.guest@example.com']"
    assert_select "input[name='rsvp[first_name]'][value='Jo']"
    # Submitting the form RSVPs for this show, not the other one.
    assert_select "input[name='rsvp[show_id]'][value='#{shows(:upcoming).id}']"
    assert_equal shows(:past), past_rsvp.reload.show
  end

  test "another show's RSVP token uses the guest's existing RSVP for this show" do
    past_rsvp = RSVP.create!(first_name: "Jo", last_name: "Guest", email: "jo.guest@example.com", show: shows(:past),
                             response: "yes", seats_reserved: 2)
    upcoming_rsvp = RSVP.create!(first_name: "Jo", last_name: "Guest", email: "jo.guest@example.com", show: shows(:upcoming),
                                 response: "yes", seats_reserved: 1)

    assert_no_difference("RSVP.count") do
      get rsvp_response_path(slug: shows(:upcoming).slug, uniqid: past_rsvp.uniqid, response: "no")
    end

    assert_redirected_to rsvp_thanks_path(uniqid: upcoming_rsvp.uniqid)
    assert_equal "no", upcoming_rsvp.reload.response
    assert_equal shows(:past), past_rsvp.reload.show
    assert_equal "yes", past_rsvp.response
  end
end
