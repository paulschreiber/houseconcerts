require "test_helper"

# Each page names itself in <title>, or gets the site name if it doesn't.
class PageTitlesTest < ActionDispatch::IntegrationTest
  delegate :site_name, to: :Settings

  def assert_title(title)
    assert_response :success
    assert_select "title", text: title
  end

  test "mailing list pages" do
    person = people(:one)
    list = "Mailing List » #{site_name}"

    get mailing_list_thanks_path(uniqid: person.uniqid)
    assert_title list

    get mailing_list_already_subscribed_path(first_name: "Jane")
    assert_title list

    get mailing_list_rejoin_requested_path
    assert_title list

    get mailing_list_rejoin_path(uniqid: person.uniqid)
    assert_title list

    get unsubscribe_path(uniqid: person.uniqid)
    assert_title list
  end

  test "the RSVP thanks page names the show" do
    rsvp = rsvps(:one)

    get rsvp_thanks_path(uniqid: rsvp.uniqid)
    assert_title "#{rsvp.show.name} » #{site_name}"
  end

  test "the privacy policy and log in pages" do
    get privacy_path
    assert_title "Privacy Policy » #{site_name}"

    get new_admin_session_path
    assert_title "Log in » #{site_name}"
  end

  test "a page that doesn't set a title gets the site name" do
    get new_admin_password_path
    assert_title site_name

    get root_path
    assert_title site_name
  end
end
