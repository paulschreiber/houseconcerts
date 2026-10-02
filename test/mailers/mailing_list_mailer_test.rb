require "test_helper"

class MailingListMailerTest < ActionMailer::TestCase
  test "rejoin emails the person a link to confirm" do
    person = people(:one)
    email = MailingListMailer.rejoin(person)

    assert_equal [ person.email ], email.to
    assert_includes email.subject, "rejoin"
    assert_includes email.body.encoded, "/list/rejoin/#{person.uniqid}"
    assert_includes email.body.decoded, "this email address (#{person.email})"
    assert_match %r{To rejoin, <a href="[^"]+">confirm your request</a>\.}, email.body.decoded
  end
end
