require "test_helper"

# Link tokens (uniqid) and SMS bodies must not appear in the logs. Names and
# phone numbers may.
class LogFilteringTest < ActionDispatch::IntegrationTest
  AUTH_TOKEN = "test-twilio-auth-token".freeze

  test "unsubscribe links don't log the token" do
    log = capture_log { get unsubscribe_path(uniqid: people(:one).uniqid) }

    assert_token_filtered log, people(:one).uniqid
    assert_includes log, %(Started GET "/unsubscribe/[FILTERED]")
  end

  test "RSVP links don't log the token" do
    log = capture_log { get modify_rsvp_path(slug: shows(:upcoming).slug, uniqid: rsvps(:one).uniqid) }

    assert_token_filtered log, rsvps(:one).uniqid
    assert_includes log, %(Started GET "/rsvps/show/#{shows(:upcoming).slug}/[FILTERED]")
  end

  test "redirects to a tokened URL don't log the token" do
    log = capture_log { get rsvp_response_path(slug: shows(:upcoming).slug, uniqid: rsvps(:one).uniqid, response: "no") }

    assert_response :redirect
    assert_token_filtered log, rsvps(:one).uniqid
    assert_includes log, "Redirected to [FILTERED]"
  end

  test "the open-tracking pixel doesn't log the token" do
    log = capture_log { get open_tracking_path(tag: "test:invite", uniqid: people(:one).uniqid, kind: "person") }

    assert_token_filtered log, people(:one).uniqid
  end

  test "incoming SMS bodies aren't logged, but the sender's number is" do
    with_twilio_auth_token do
      params = { "From" => "+15551234567", "Body" => "my secret message" }
      signature = Twilio::Security::RequestValidator.new(AUTH_TOKEN).build_signature_for(sms_url, params)

      log = capture_log { post sms_url, params: params, headers: { "X-Twilio-Signature" => signature } }

      assert_response :success
      assert_not_includes log, "my secret message"
      assert_includes log, "+15551234567"
      assert_includes log, "Enqueued ActionMailer::MailDeliveryJob"
    end
  end

  private

    def assert_token_filtered(log, token)
      assert_not_includes log, token
      assert_includes log, "[FILTERED]"
    end

    # Everything logged during the block, at production's log level.
    def capture_log
      io = StringIO.new
      logger = ActiveSupport::Logger.new(io, level: :info)
      Rails.logger.broadcast_to(logger)
      yield
      io.string
    ensure
      Rails.logger.stop_broadcasting_to(logger)
    end

    # Set via ENV rather than credentials, so this doesn't need a master key.
    def with_twilio_auth_token
      original = ENV.fetch("TWILIO_AUTH_TOKEN", nil)
      ENV["TWILIO_AUTH_TOKEN"] = AUTH_TOKEN
      yield
    ensure
      ENV["TWILIO_AUTH_TOKEN"] = original
    end
end
