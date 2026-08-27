require "test_helper"

class RsvpsControllerTest < ActionDispatch::IntegrationTest
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

  test "create recovers when a concurrent request wins the race for the same show and email" do
    show = shows(:upcoming)
    email = "race.condition@example.com"

    # Simulate two requests that both miss the initial find_by: the first
    # call to #save creates the "winning" row out from under us and raises
    # the DB's unique-index violation, exactly like a concurrent request
    # would; the second call (our recovery update) behaves normally.
    original_save = RSVP.instance_method(:save)
    raced = false
    RSVP.send(:define_method, :save) do |*args, **kwargs|
      if raced
        original_save.bind_call(self, *args, **kwargs)
      else
        raced = true
        RSVP.create!(show_id: show.id, email: email, first_name: "Winner", last_name: "Row", response: "yes", seats_reserved: 2)
        raise ActiveRecord::RecordNotUnique, "Duplicate entry for key 'index_rsvps_on_show_id_and_email'"
      end
    end

    begin
      assert_difference("RSVP.count", 1) do
        post rsvps_path, params: {
          rsvp: {
            first_name: "Loser",
            last_name: "Row",
            email: email,
            show_id: show.id,
            response: "yes",
            seats_reserved: 1
          }
        }
      end
    ensure
      RSVP.send(:define_method, :save, original_save)
    end

    winner = RSVP.find_by(show_id: show.id, email: email)
    assert_equal 1, RSVP.where(show_id: show.id, email: email).count
    assert_redirected_to rsvp_thanks_path(uniqid: winner.uniqid)
    assert_equal "Loser", winner.first_name
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

  test "create with a blank name shows a validation error for each blank field" do
    assert_no_difference("RSVP.count") do
      post rsvps_path, params: {
        rsvp: {
          first_name: "",
          last_name: "",
          email: "new.attendee@example.com",
          show_id: shows(:upcoming).id,
          response: "yes",
          seats_reserved: 2
        }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error", count: 2
    assert_select ".error", text: "Enter your first name"
    assert_select ".error", text: "Enter your last name"
  end

  test "create with an invalid email format shows only the email error" do
    assert_no_difference("RSVP.count") do
      post rsvps_path, params: {
        rsvp: {
          first_name: "New",
          last_name: "Attendee",
          email: "not-an-email",
          show_id: shows(:upcoming).id,
          response: "yes",
          seats_reserved: 2
        }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error", count: 1
    assert_select ".error", text: "Enter your email address"
  end

  test "create with out-of-range seats for a 'yes' response shows only the seats error" do
    assert_no_difference("RSVP.count") do
      post rsvps_path, params: {
        rsvp: {
          first_name: "New",
          last_name: "Attendee",
          email: "new.attendee@example.com",
          show_id: shows(:upcoming).id,
          response: "yes",
          seats_reserved: Settings.show.max_seats + 1
        }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error", count: 1
    assert_select ".error", text: "Select the number of seats you want"
  end

  test "create for a sold out show with a 'yes' response shows only the show error" do
    assert_no_difference("RSVP.count") do
      post rsvps_path, params: {
        rsvp: {
          first_name: "New",
          last_name: "Attendee",
          email: "new.attendee@example.com",
          show_id: shows(:sold_out).id,
          response: "yes",
          seats_reserved: 2
        }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error", count: 1
    assert_select ".error", text: "is sold out"
  end

  test "create for a sold out show with a 'no' response succeeds since seat/availability checks are skipped" do
    assert_difference("RSVP.count", 1) do
      post rsvps_path, params: {
        rsvp: {
          first_name: "New",
          last_name: "Attendee",
          email: "new.attendee@example.com",
          show_id: shows(:sold_out).id,
          response: "no"
        }
      }
    end

    new_rsvp = RSVP.last
    assert_redirected_to rsvp_thanks_path(uniqid: new_rsvp.uniqid)
  end

  test "create redirects home instead of crashing when show_id is blank" do
    assert_no_difference("RSVP.count") do
      post rsvps_path, params: {
        rsvp: {
          first_name: "New",
          last_name: "Attendee",
          email: "new.attendee@example.com",
          show_id: "",
          response: "yes",
          seats_reserved: 2
        }
      }
    end

    assert_redirected_to root_url
  end

  test "create redirects home instead of crashing when show_id refers to a nonexistent show" do
    assert_no_difference("RSVP.count") do
      post rsvps_path, params: {
        rsvp: {
          first_name: "New",
          last_name: "Attendee",
          email: "new.attendee@example.com",
          show_id: Show.maximum(:id).to_i + 1,
          response: "yes",
          seats_reserved: 2
        }
      }
    end

    assert_redirected_to root_url
  end

  test "thanks shows the confirmation page for a valid uniqid" do
    get rsvp_thanks_path(uniqid: rsvps(:one).uniqid)
    assert_response :success
    assert_includes response.body, rsvps(:one).show.name
    assert_match(/You.ll receive my address/, response.body)
  end

  test "thanks redirects home for an invalid uniqid" do
    get rsvp_thanks_path(uniqid: "nonexistent-uniqid")
    assert_redirected_to root_url
  end

  test "thanks redirects home when the rsvp's show is not confirmed" do
    rsvp = rsvps(:one)
    rsvp.show.update!(status: "cancelled")

    get rsvp_thanks_path(uniqid: rsvp.uniqid)
    assert_redirected_to root_url
  end

  test "thanks redirects home when the rsvp's show already occurred" do
    rsvp = rsvps(:one)
    rsvp.update!(show: shows(:past))

    get rsvp_thanks_path(uniqid: rsvp.uniqid)
    assert_redirected_to root_url
  end
end
