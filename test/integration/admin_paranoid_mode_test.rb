require "test_helper"

# Devise's paranoid mode: responses must not reveal whether an email belongs
# to an admin, either in what they say or in how long they take.
class AdminParanoidModeTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  PARANOID_RESET_NOTICE = "If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes.".freeze

  setup do
    admins(:one).update!(password: "correct horse battery staple")
  end

  test "the password reset form responds the same for admin and unknown emails" do
    responses = [ admins(:one).email, "nobody@example.com" ].map do |email|
      post admin_password_path, params: { admin: { email: email } }
      status = response.status
      follow_redirect!
      [ status, flash[:notice] ]
    end

    assert_equal responses.first, responses.last
    assert_equal [ 303, PARANOID_RESET_NOTICE ], responses.first
  end

  test "only a real admin email gets a reset email" do
    assert_emails(1) { post admin_password_path, params: { admin: { email: admins(:one).email } } }
    assert_no_emails { post admin_password_path, params: { admin: { email: "nobody@example.com" } } }
  end

  # Delivering inline (an SMTP round trip) would make a real admin's reset
  # request measurably slower than an unknown email's.
  test "the reset email is sent in the background, not during the request" do
    assert_enqueued_emails(1) { post admin_password_path, params: { admin: { email: admins(:one).email } } }
    assert_empty ActionMailer::Base.deliveries
  end

  # A failed sign-in for a real admin runs bcrypt to check the password; one for
  # an unknown email must do the same amount of bcrypt work, or it's measurably
  # faster.
  test "a failed sign-in does the same password hashing for admin and unknown emails" do
    work = [ admins(:one).email, "nobody@example.com" ].map do |email|
      bcrypt_operations_during { post admin_session_path, params: { admin: { email: email, password: "a guess" } } }
    end

    assert_equal work.first, work.last, "bcrypt operations (admin, unknown): #{work.inspect}"
    assert_select "p.alert", "Invalid email or password."
  end

  test "signing in with a wrong password for an admin shows the same message" do
    post admin_session_path, params: { admin: { email: admins(:one).email, password: "a guess" } }

    assert_select "p.alert", "Invalid email or password."
  end

  private

    # Counts Devise's bcrypt operations: hashing a password and comparing one.
    # (Object#stub isn't available on this repo's Minitest, so swap the methods
    # by hand.)
    def bcrypt_operations_during
      calls = 0
      originals = %i[digest compare].index_with { |name| Devise::Encryptor.method(name) }
      originals.each do |name, original|
        Devise::Encryptor.define_singleton_method(name) do |*args|
          calls += 1
          original.call(*args)
        end
      end
      yield
      calls
    ensure
      originals.each { |name, original| Devise::Encryptor.define_singleton_method(name, original) }
    end
end
