require "test_helper"

class RsvpsControllerTest < ActionDispatch::IntegrationTest
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

  test "new with a 'no' response for a person with no existing rsvp saves and redirects to thanks" do
    assert_difference("RSVP.count", 1) do
      get rsvp_response_path(slug: shows(:upcoming).slug, uniqid: people(:one).uniqid, response: "no")
    end

    new_rsvp = RSVP.last
    assert_equal "no", new_rsvp.response
    assert_redirected_to rsvp_thanks_path(uniqid: new_rsvp.uniqid)
  end

  test "create saves a new rsvp and redirects to thanks" do
    assert_difference("RSVP.count", 1) do
      post rsvps_path, params: {
        rsvp: {
          first_name: "New",
          last_name: "Attendee",
          email: "new.attendee@example.com",
          show_id: shows(:upcoming).id,
          response: "yes",
          seats_reserved: 2
        }
      }
    end

    new_rsvp = RSVP.last
    assert_equal "new.attendee@example.com", new_rsvp.email
    assert_redirected_to rsvp_thanks_path(uniqid: new_rsvp.uniqid)
  end

  test "create updates an existing reservation for the same email and show instead of creating a new one" do
    assert_no_difference("RSVP.count") do
      post rsvps_path, params: {
        rsvp: {
          first_name: rsvps(:one).first_name,
          last_name: rsvps(:one).last_name,
          email: rsvps(:one).email,
          show_id: rsvps(:one).show_id,
          response: "yes",
          seats_reserved: 3
        }
      }
    end

    assert_equal 3, rsvps(:one).reload.seats_reserved
    assert_redirected_to rsvp_thanks_path(uniqid: rsvps(:one).uniqid)
  end

  test "create renders the form with 422 on validation failure" do
    assert_no_difference("RSVP.count") do
      post rsvps_path, params: {
        rsvp: {
          first_name: "",
          last_name: "Attendee",
          email: "invalid@example.com",
          show_id: shows(:upcoming).id,
          response: "yes",
          seats_reserved: 2
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "thanks shows the confirmation page for a valid uniqid" do
    get rsvp_thanks_path(uniqid: rsvps(:one).uniqid)
    assert_response :success
    assert_includes response.body, rsvps(:one).show.name
  end

  test "thanks redirects home for an invalid uniqid" do
    get rsvp_thanks_path(uniqid: "nonexistent-uniqid")
    assert_redirected_to root_url
  end
end
