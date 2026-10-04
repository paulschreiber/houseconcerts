require "test_helper"

class SesEventsControllerTest < ActionDispatch::IntegrationTest
  # Set via ENV rather than read from Rails.application.credentials, so these
  # tests don't depend on a master key being available (e.g. in CI).
  TOKEN = "test-ses-events-token".freeze

  setup do
    @original_token = ENV.fetch("SES_EVENTS_TOKEN", nil)
    ENV["SES_EVENTS_TOKEN"] = TOKEN
    @person = people(:one)
  end

  teardown do
    ENV["SES_EVENTS_TOKEN"] = @original_token
  end

  test "a permanent bounce marks the person bouncing" do
    deliver(bounce("Permanent", @person.email.upcase))

    assert_response :no_content
    assert_predicate @person.reload, :bouncing?
  end

  test "a transient bounce changes nothing" do
    deliver(bounce("Transient", @person.email))

    assert_response :no_content
    assert_predicate @person.reload, :active?
  end

  test "a complaint removes the person" do
    deliver(complaint(@person.email))

    assert_response :no_content
    @person.reload
    assert_predicate @person, :removed?
    assert_not_nil @person.removed_at
  end

  test "a bounce doesn't undo an unsubscribe" do
    @person.removed!

    deliver(bounce("Permanent", @person.email))

    assert_response :no_content
    assert_predicate @person.reload, :removed?
  end

  test "the same event twice changes nothing the second time" do
    event = complaint(@person.email)
    deliver(event)
    removed_at = @person.reload.removed_at

    travel 1.hour do
      deliver(event)
    end

    assert_response :no_content
    assert_equal removed_at, @person.reload.removed_at
  end

  test "other events and unknown addresses are ignored" do
    deliver(envelope("Email Delivered", "eventType" => "Delivery", "mail" => mail("someone@example.com")))

    assert_response :no_content

    deliver(bounce("Permanent", "nobody@example.com"))

    assert_response :no_content
    assert_predicate @person.reload, :active?
  end

  test "a request without the right token is refused and changes nothing" do
    [ nil, "wrong-token" ].each do |token|
      headers = { "CONTENT_TYPE" => "application/json" }
      headers[SesEventsController::TOKEN_HEADER] = token if token
      post ses_events_path, params: complaint(@person.email).to_json, headers: headers

      assert_response :unauthorized, token.inspect
    end
    assert_predicate @person.reload, :active?
  end

  test "every request is refused until the token is configured" do
    ENV["SES_EVENTS_TOKEN"] = nil

    deliver(complaint(@person.email), token: "")

    assert_response :unauthorized
    assert_predicate @person.reload, :active?
  end

  test "malformed JSON is a bad request" do
    post ses_events_path, params: "{not json", headers: { "CONTENT_TYPE" => "application/json",
                                                          SesEventsController::TOKEN_HEADER => TOKEN }

    assert_response :bad_request
  end

  test "the event details are filtered from the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter(bounce("Permanent", @person.email))["detail"]
  end

  private

    def deliver(event, token: TOKEN)
      post ses_events_path, params: event.to_json,
                            headers: { "CONTENT_TYPE" => "application/json", SesEventsController::TOKEN_HEADER => token }
    end

    # The shape EventBridge delivers SES events in: its envelope, with the SES
    # event itself as "detail".
    def envelope(detail_type, detail)
      { "version" => "0", "id" => SecureRandom.uuid, "detail-type" => detail_type, "source" => "aws.ses",
        "account" => "123456789012", "time" => "2026-10-03T20:44:39Z", "region" => "us-east-1",
        "resources" => [ "arn:aws:ses:us-east-1:123456789012:configuration-set/houseconcerts" ], "detail" => detail }
    end

    def mail(recipient)
      { "timestamp" => "2026-10-03T20:44:35.128Z", "source" => "invites@example.com",
        "messageId" => "010001a10382efb8-18c49095-5b62-4e7d-b58a-95324e4f081e-000000", "destination" => [ recipient ] }
    end

    def bounce(type, recipient)
      envelope("Email Bounced",
               "eventType" => "Bounce",
               "bounce" => { "bounceType" => type, "bounceSubType" => "General",
                             "bouncedRecipients" => [ { "emailAddress" => recipient, "action" => "failed",
                                                        "status" => "5.1.1", "diagnosticCode" => "smtp; 550 5.1.1 user unknown" } ],
                             "timestamp" => "2026-10-03T20:44:39Z", "feedbackId" => "0100-feedback" },
               "mail" => mail(recipient))
    end

    def complaint(recipient)
      envelope("Email Complaint Received",
               "eventType" => "Complaint",
               "complaint" => { "complainedRecipients" => [ { "emailAddress" => recipient } ],
                                "complaintFeedbackType" => "abuse", "timestamp" => "2026-10-03T20:50:00Z",
                                "feedbackId" => "0100-feedback" },
               "mail" => mail(recipient))
    end
end
