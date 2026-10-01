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
end
