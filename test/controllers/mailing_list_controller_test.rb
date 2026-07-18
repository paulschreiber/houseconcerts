require "test_helper"

class MailingListControllerTest < ActionDispatch::IntegrationTest
  test "index renders the signup form" do
    get mailing_list_path
    assert_response :success
    assert_select "form"
  end

  test "unsubscribe redirects home for an unknown uniqid" do
    get unsubscribe_path(uniqid: "nonexistent-uniqid")
    assert_redirected_to root_url
  end

  test "unsubscribe marks an active person as removed" do
    person = people(:one)
    assert_not person.removed?

    get unsubscribe_path(uniqid: person.uniqid)

    assert_response :success
    assert person.reload.removed?
  end

  test "unsubscribe shows an already-removed message for a person already removed" do
    person = people(:one)
    person.update!(status: "removed")

    get unsubscribe_path(uniqid: person.uniqid)

    assert_response :success
    assert_includes response.body, "Not a subscriber"
  end

  test "create signs up a new person and redirects to thanks" do
    assert_difference("Person.count", 1) do
      post people_path, params: {
        person: {
          first_name: "New",
          last_name: "Subscriber",
          email: "new.subscriber@example.com"
        }
      }
    end

    new_person = Person.last
    assert_equal "new.subscriber@example.com", new_person.email
    assert_redirected_to mailing_list_thanks_path(uniqid: new_person.uniqid)
  end

  test "create redirects to already_subscribed for an existing email" do
    assert_no_difference("Person.count") do
      post people_path, params: {
        person: {
          first_name: "Whatever",
          last_name: "Name",
          email: people(:one).email
        }
      }
    end

    assert_redirected_to mailing_list_already_subscribed_path(uniqid: people(:one).uniqid)
  end

  test "create renders the form with 422 on validation failure" do
    assert_no_difference("Person.count") do
      post people_path, params: {
        person: {
          first_name: "",
          last_name: "Subscriber",
          email: "invalid.subscriber@example.com"
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "thanks shows the confirmation page for a valid uniqid" do
    get mailing_list_thanks_path(uniqid: people(:one).uniqid)
    assert_response :success
    assert_includes response.body, people(:one).first_name
  end

  test "thanks redirects home for an invalid uniqid" do
    get mailing_list_thanks_path(uniqid: "nonexistent-uniqid")
    assert_redirected_to root_url
  end

  test "already_subscribed shows the message for a valid uniqid" do
    get mailing_list_already_subscribed_path(uniqid: people(:one).uniqid)
    assert_response :success
    assert_includes response.body, people(:one).first_name
  end

  test "already_subscribed redirects home for an invalid uniqid" do
    get mailing_list_already_subscribed_path(uniqid: "nonexistent-uniqid")
    assert_redirected_to root_url
  end
end
