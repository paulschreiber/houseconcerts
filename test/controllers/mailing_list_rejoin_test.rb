require "test_helper"

class MailingListRejoinTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @person = people(:one)
    @person.update!(status: :removed)
    # The test environment's null_store cache can't hold the once-an-hour
    # rejoin email limit, so swap in a real cache for these tests.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  def sign_up(email)
    post people_path, params: { person: { first_name: "Jane", last_name: "Smith", email: email } }
  end

  test "signing up again after unsubscribing emails a rejoin link instead of saying already subscribed" do
    assert_enqueued_email_with MailingListMailer, :rejoin, args: [ @person ] do
      sign_up @person.email
    end

    assert_redirected_to mailing_list_rejoin_requested_path
    follow_redirect!
    assert_select "h1", "Confirm your rejoin request via email"
    assert_select "p", text: /This email address \(#{Regexp.escape(@person.email)}\) was unsubscribed/
    assert_predicate @person.reload, :removed?
  end

  test "the rejoin request page still makes sense without the address, e.g. on reload" do
    get mailing_list_rejoin_requested_path

    assert_response :success
    assert_select "p", text: /\AThis email address was unsubscribed/
  end

  test "bouncing and moved addresses also get a rejoin link" do
    %w[bouncing moved].each do |status|
      @person.update!(status: status)
      Rails.cache.clear

      assert_enqueued_email_with(MailingListMailer, :rejoin, args: [ @person ]) { sign_up @person.email }
      assert_redirected_to mailing_list_rejoin_requested_path
    end
  end

  test "active subscribers are still told they're already subscribed" do
    @person.update!(status: :active)

    assert_no_enqueued_emails { sign_up @person.email }
    assert_redirected_to mailing_list_already_subscribed_path(first_name: "Jane")
  end

  test "sends at most one rejoin email per hour" do
    assert_enqueued_emails(1) do
      3.times { sign_up @person.email }
    end
    assert_redirected_to mailing_list_rejoin_requested_path
  end

  test "the rejoin link shows a confirm button and doesn't resubscribe on its own" do
    get mailing_list_rejoin_path(uniqid: @person.uniqid)

    assert_response :success
    assert_select "form[action='#{mailing_list_rejoin_path(uniqid: @person.uniqid)}'][method=post] button", "Add me back to the mailing list"
    assert_predicate @person.reload, :removed?
  end

  test "confirming resubscribes the person" do
    post mailing_list_rejoin_path(uniqid: @person.uniqid)

    assert_redirected_to mailing_list_thanks_path(uniqid: @person.uniqid)
    @person.reload
    assert_predicate @person, :active?
    assert_nil @person.removed_at
    assert_nil @person.removal_ip_address
  end

  test "the rejoin link says so when the person is already active" do
    @person.update!(status: :active)

    get mailing_list_rejoin_path(uniqid: @person.uniqid)

    assert_select ".pagetext", /already on my mailing list/
    assert_select "form", false
  end

  test "unknown rejoin tokens redirect home" do
    get mailing_list_rejoin_path(uniqid: "nonexistent")
    assert_redirected_to root_url

    post mailing_list_rejoin_path(uniqid: "nonexistent")
    assert_redirected_to root_url
  end
end
