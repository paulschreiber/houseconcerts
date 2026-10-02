require "test_helper"

# The per-email sign-in throttle can't lock an admin out of a browser they've
# signed in from before (see AdminTrustedDevice).
class AdminTrustedDeviceTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct horse battery staple".freeze

  setup do
    # The test environment's null_store cache can't hold rack-attack's
    # throttle counters across requests, so swap in a real cache.
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    admins(:one).update!(password: PASSWORD)
    @ip = 0
  end

  teardown do
    Rack::Attack.cache.store = @original_store
  end

  test "a browser the admin signed in from can still sign in once the email is locked out" do
    trusted = browser
    sign_in(trusted, password: PASSWORD)
    trusted.delete destroy_admin_session_path

    lock_out(admins(:one).email)

    sign_in(trusted, password: PASSWORD).assert_response :see_other
    trusted.get madmin_root_path

    trusted.assert_response :success
  end

  test "a browser without the cookie is still locked out" do
    lock_out(admins(:one).email)

    sign_in(browser, password: PASSWORD).assert_response :too_many_requests
  end

  test "a forged cookie doesn't skip the throttle" do
    lock_out(admins(:one).email)
    forged = browser
    forged.cookies[AdminTrustedDevice::COOKIE.to_s] = "forged"

    sign_in(forged, password: PASSWORD).assert_response :too_many_requests
  end

  test "the cookie only helps the admin who signed in from that browser" do
    admins(:two).update!(password: PASSWORD)
    trusted = browser
    sign_in(trusted, password: PASSWORD)

    lock_out(admins(:two).email)

    sign_in(trusted, email: admins(:two).email, password: PASSWORD).assert_response :too_many_requests
  end

  test "a trusted browser has its own sign-in limit" do
    trusted = browser
    sign_in(trusted, password: PASSWORD)
    trusted.delete destroy_admin_session_path

    10.times { sign_in(trusted, password: "a guess") }

    trusted.assert_response :unprocessable_entity

    sign_in(trusted, password: PASSWORD).assert_response :too_many_requests
  end

  test "a failed sign-in doesn't set the cookie" do
    untrusted = browser
    sign_in(untrusted, password: "a guess")

    assert_predicate untrusted.cookies[AdminTrustedDevice::COOKIE.to_s], :blank?
  end

  private

    def browser = open_session

    # Each attempt from a new IP, so the per-IP throttle doesn't interfere.
    def sign_in(session, password:, email: admins(:one).email)
      @ip += 1
      session.post admin_session_path, params: { admin: { email: email, password: password } },
                                       env: { "REMOTE_ADDR" => "198.51.100.#{@ip}" }
      session
    end

    # Uses up the per-email limit from a browser without the cookie (earlier
    # sign-ins for the email may already count toward it).
    def lock_out(email)
      attacker = browser
      11.times do
        sign_in(attacker, email: email, password: "a guess")
        break if attacker.response.status == 429
      end
      attacker.assert_response :too_many_requests
    end
end
