require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    # The test environment's null_store cache can't hold rack-attack's
    # throttle counters across requests, so swap in a real cache for the
    # duration of this test.
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.cache.store = @original_store
  end

  test "throttles repeated requests to a uniqid-keyed path from the same ip" do
    20.times { get open_tracking_path(tag: "test:invite", uniqid: "nonexistent") }

    assert_response :success

    get open_tracking_path(tag: "test:invite", uniqid: "nonexistent")

    assert_response :too_many_requests
  end

  test "does not throttle a path that isn't uniqid-keyed" do
    25.times { get root_path }

    assert_response :success
  end

  test "throttles repeated admin sign-in attempts from the same ip" do
    5.times { post admin_session_path, params: { admin: { email: "admin-#{rand}@example.com", password: "guess" } } }

    assert_not_equal 429, response.status

    post admin_session_path, params: { admin: { email: "another@example.com", password: "guess" } }

    assert_response :too_many_requests
  end

  test "throttles repeated admin sign-in attempts for the same email from different ips" do
    10.times do |i|
      post admin_session_path, params: { admin: { email: "Admin-One@Example.com ", password: "guess" } }, env: { "REMOTE_ADDR" => "198.51.100.#{i}" }
    end

    assert_not_equal 429, response.status

    post admin_session_path, params: { admin: { email: "admin-one@example.com", password: "guess" } }, env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_response :too_many_requests
  end

  test "throttles repeated password reset requests from the same ip" do
    5.times { |i| post admin_password_path, params: { admin: { email: "reset-#{i}@example.com" } } }

    assert_not_equal 429, response.status

    post admin_password_path, params: { admin: { email: "reset-6@example.com" } }

    assert_response :too_many_requests
  end

  test "throttles repeated password reset requests for the same email from different ips" do
    3.times do |i|
      post admin_password_path, params: { admin: { email: admins(:one).email } }, env: { "REMOTE_ADDR" => "198.51.100.#{i}" }
    end

    assert_not_equal 429, response.status

    post admin_password_path, params: { admin: { email: admins(:one).email.upcase } }, env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_response :too_many_requests
  end

  test "does not throttle viewing the sign-in page" do
    10.times { get new_admin_session_path }

    assert_response :success
  end

  test "admin sign-in throttles also apply with a format suffix" do
    %w[.json .html].each_with_index do |suffix, i|
      Rack::Attack.cache.store.clear
      ip = "198.51.100.#{i}"
      5.times { post "#{admin_session_path}#{suffix}", params: { admin: { email: "x#{rand}@example.com", password: "guess" } }, env: { "REMOTE_ADDR" => ip } }

      assert_not_equal 429, response.status, suffix

      post "#{admin_session_path}#{suffix}", params: { admin: { email: "y@example.com", password: "guess" } }, env: { "REMOTE_ADDR" => ip }

      assert_response :too_many_requests, suffix
    end
  end

  test "password reset throttles also apply with a format suffix" do
    3.times do |i|
      post "#{admin_password_path}.json", params: { admin: { email: admins(:one).email } }, env: { "REMOTE_ADDR" => "198.51.100.#{i}" }
    end

    post "#{admin_password_path}.json", params: { admin: { email: admins(:one).email } }, env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_response :too_many_requests
  end

  test "a malformed admin param doesn't break the email throttles" do
    post admin_session_path, params: "admin=not-a-hash", headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }

    assert_not_equal 500, response.status
  end

  test "throttles repeated RSVP submissions from the same ip" do
    20.times { |i| post rsvps_path, params: { rsvp: { email: "guest-#{i}@example.com", show_id: 0 } } }

    assert_not_equal 429, response.status

    patch rsvps_path, params: { rsvp: { email: "guest-21@example.com", show_id: 0 } }

    assert_response :too_many_requests

    post rsvps_path, params: { rsvp: { email: "guest-22@example.com", show_id: 0 } }, env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_not_equal 429, response.status
  end

  test "throttles repeated RSVP submissions for the same email from different ips" do
    10.times do |i|
      post rsvps_path, params: { rsvp: { email: "Guest@Example.com ", show_id: 0 } }, env: { "REMOTE_ADDR" => "198.51.100.#{i}" }
    end

    assert_not_equal 429, response.status

    patch rsvps_path, params: { rsvp: { email: "guest@example.com", show_id: 0 } }, env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_response :too_many_requests
  end

  test "throttles repeated mailing list signups from the same ip" do
    10.times { |i| post people_path, params: { person: { email: "signup-#{i}@example.com" } } }

    assert_not_equal 429, response.status

    post people_path, params: { person: { email: "signup-11@example.com" } }

    assert_response :too_many_requests
  end

  test "limits mailing list signups from the same ip per day" do
    4.times do |window|
      travel_to Time.zone.parse("2026-10-02 00:00") + (window * 15).minutes do
        10.times { |i| post people_path, params: { person: { email: "signup-#{window}-#{i}@example.com" } } }

        assert_not_equal 429, response.status, "window #{window}"
      end
    end

    travel_to Time.zone.parse("2026-10-02 01:00") do
      post people_path, params: { person: { email: "one-more@example.com" } }

      assert_response :too_many_requests
    end
  end

  test "public form throttles also apply with a format suffix" do
    20.times { |i| post "#{rsvps_path}.json", params: { rsvp: { email: "guest-#{i}@example.com", show_id: 0 } } }
    post "#{rsvps_path}.json", params: { rsvp: { email: "guest-21@example.com", show_id: 0 } }

    assert_response :too_many_requests

    10.times { |i| post "#{people_path}.html", params: { person: { email: "signup-#{i}@example.com" } } }
    post "#{people_path}.html", params: { person: { email: "signup-11@example.com" } }

    assert_response :too_many_requests
  end

  test "a throttled request gets the try-again page and a Retry-After header" do
    11.times { |i| post people_path, params: { person: { email: "signup-#{i}@example.com" } } }

    assert_response :too_many_requests
    assert_equal "text/html; charset=utf-8", response.headers["content-type"]
    assert_includes response.body, "Please wait a few minutes and try again."
    assert_includes 1..600, response.headers["retry-after"].to_i
  end

  test "form_email ignores malformed params" do
    [ "rsvp=not-a-hash", "rsvp[email][]=a@example.com", "" ].each do |body|
      req = Rack::Attack::Request.new(Rack::MockRequest.env_for("/rsvps", method: "POST", input: body, "CONTENT_TYPE" => "application/x-www-form-urlencoded"))

      assert_nil Rack::Attack.form_email(req, "rsvp"), body
    end
  end

  test "the per-email throttles also count JSON bodies" do
    json = { "CONTENT_TYPE" => "application/json" }

    10.times do |i|
      post admin_session_path, params: { admin: { email: admins(:one).email, password: "guess" } }.to_json,
                               headers: json, env: { "REMOTE_ADDR" => "198.51.100.#{i}" }
    end
    post admin_session_path, params: { admin: { email: admins(:one).email, password: "guess" } }.to_json,
                             headers: json, env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_response :too_many_requests

    10.times do |i|
      post rsvps_path, params: { rsvp: { email: "guest@example.com", show_id: 0 } }.to_json,
                       headers: json, env: { "REMOTE_ADDR" => "198.51.100.#{i}" }
    end
    post rsvps_path, params: { rsvp: { email: "guest@example.com", show_id: 0 } }.to_json,
                     headers: json, env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_response :too_many_requests
  end

  test "form_email treats unparseable JSON as no email" do
    req = Rack::Attack::Request.new(Rack::MockRequest.env_for("/rsvps", method: "POST", input: "{not json", "CONTENT_TYPE" => "application/json"))

    assert_nil Rack::Attack.form_email(req, "rsvp")
  end

  test "throttles repeated passkey creation attempts from the same ip" do
    5.times { post admin_passkeys_path }

    assert_not_equal 429, response.status

    post admin_passkeys_path

    assert_response :too_many_requests
  end

  test "passkey creation throttle also applies with a format suffix" do
    5.times { post "#{admin_passkeys_path}.json" }

    assert_not_equal 429, response.status

    post "#{admin_passkeys_path}.json"

    assert_response :too_many_requests
  end

  test "throttles passkey creation per signed-in admin across ips" do
    sign_in admins(:one)

    10.times { |i| post admin_passkeys_path, env: { "REMOTE_ADDR" => "198.51.100.#{i}" } }

    assert_not_equal 429, response.status

    post admin_passkeys_path, env: { "REMOTE_ADDR" => "198.51.100.200" }

    assert_response :too_many_requests
  end
end
