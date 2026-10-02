require "test_helper"

# The RSVP and mailing-list pages only answer HTML (see HtmlOnly).
class HtmlOnlyTest < ActionDispatch::IntegrationTest
  JSON_BODY = { "CONTENT_TYPE" => "application/json" }.freeze

  setup do
    @show = shows(:upcoming)
  end

  test "the RSVP and mailing-list routes don't take a format suffix" do
    [
      [ :get, "#{rsvp_for_show_path(slug: @show.slug)}.json" ],
      [ :post, "#{rsvps_path}.json" ],
      [ :patch, "#{rsvps_path}.json" ],
      [ :get, "#{mailing_list_path}.json" ],
      [ :post, "#{people_path}.json" ],
      [ :get, "#{unsubscribe_path(uniqid: people(:one).uniqid)}.json" ]
    ].each do |verb, path|
      public_send(verb, path)

      assert_response :not_found, "#{verb.upcase} #{path}"
    end
  end

  test "asking for JSON gets a 406 and changes nothing" do
    json = { "Accept" => "application/json" }

    assert_no_difference -> { RSVP.count } do
      post rsvps_path, params: rsvp_params, headers: json
    end
    assert_response :not_acceptable

    assert_no_difference -> { Person.count } do
      post people_path, params: person_params, headers: json
    end
    assert_response :not_acceptable

    get rsvp_for_show_path(slug: @show.slug), headers: json

    assert_response :not_acceptable
  end

  test "a JSON body gets a 415 and changes nothing" do
    assert_no_difference -> { RSVP.count } do
      post rsvps_path, params: rsvp_params.to_json, headers: JSON_BODY
    end
    assert_response :unsupported_media_type

    assert_no_difference -> { Person.count } do
      post people_path, params: person_params.to_json, headers: JSON_BODY
    end
    assert_response :unsupported_media_type
  end

  test "Turbo form submissions still work" do
    turbo = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }

    assert_difference -> { Person.count }, 1 do
      post people_path, params: person_params, headers: turbo
    end
    assert_response :redirect

    post rsvps_path, params: { rsvp: { email: "not-an-email", show_id: @show.id } }, headers: turbo

    assert_response :unprocessable_content
  end

  test "*/* still gets the HTML page, so link previews work" do
    get rsvp_for_show_path(slug: @show.slug), headers: { "Accept" => "*/*" }

    assert_response :success
    assert_equal "text/html", response.media_type
  end

  private

    def rsvp_params
      { rsvp: { first_name: "Jo", last_name: "Guest", email: "jo.guest@example.com", show_id: @show.id,
                response: "yes", seats_reserved: 1, postcode: "10001" } }
    end

    def person_params
      { person: { first_name: "Jo", last_name: "Guest", email: "jo.guest@example.com", postcode: "10001" } }
    end
end
