require "test_helper"

class InviteMessageTest < ActiveSupport::TestCase
  include BatchTestHelpers

  LINKS = { rsvp_yes: "https://example.com/yes", rsvp_no: "https://example.com/no", rsvp: "https://example.com/rsvp" }.freeze

  def invite_message
    invite_messages(:upcoming)
  end

  def new_revision(**attrs)
    show.invite_messages.create!({ intro: "Intro", about: "About" }.merge(attrs))
  end

  test "fixture is valid" do
    assert_predicate invite_message, :valid?
  end

  test "requires an intro and an about" do
    message = show.invite_messages.new

    assert_not message.valid?
    assert_includes message.errors[:intro], "can't be blank"
    assert_includes message.errors[:about], "can't be blank"
  end

  test "limits the intro and about to 10,000 characters" do
    assert_predicate show.invite_messages.new(intro: "a" * 10_000, about: "a" * 10_000), :valid?

    message = show.invite_messages.new(intro: "a" * 10_001, about: "a" * 10_001)
    assert_not message.valid?
    assert_includes message.errors[:intro], "is too long (maximum is 10000 characters)"
    assert_includes message.errors[:about], "is too long (maximum is 10000 characters)"
  end

  test "numbers each show's revisions from 1" do
    assert_equal 2, new_revision.revision
    assert_equal 3, new_revision.revision
    assert_equal 1, shows(:sold_out).invite_messages.create!(intro: "Intro", about: "About").revision
  end

  test "the show's invite_message is its highest revision" do
    assert_equal invite_message, show.invite_message
    assert_predicate invite_message, :current?

    second = new_revision
    assert_equal second, show.reload.invite_message
    assert_not invite_message.current?
  end

  test "renders bold, italics, strikethrough and links" do
    message = InviteMessage.new(intro: "Some **bold**, *italic*, ~~struck~~ and [linked](https://example.com) text.")

    assert_equal %(<p>Some <strong>bold</strong>, <em>italic</em>, <del>struck</del> and <a href="https://example.com">linked</a> text.</p>\n),
                 message.intro_html(LINKS)
  end

  test "renders a blank line as a new paragraph" do
    assert_equal "<p>One</p>\n\n<p>Two</p>\n", InviteMessage.new(about: "One\n\nTwo").about_html(LINKS)
  end

  test "fills in each placeholder link with the recipient's URL" do
    message = InviteMessage.new(intro: "[Yes][rsvp_yes], [no][rsvp_no] or [change it][RSVP]")

    html = message.intro_html(LINKS)

    assert_includes html, %(<a href="https://example.com/yes">Yes</a>)
    assert_includes html, %(<a href="https://example.com/no">no</a>)
    assert_includes html, %(<a href="https://example.com/rsvp">change it</a>)
  end

  test "escapes HTML and drops other Markdown formatting to its text" do
    html = InviteMessage.new(intro: "<script>alert(1)</script> <cite>Album</cite>\n\n# Heading\n\n![image](https://example.com/a.png)").intro_html(LINKS)

    assert_includes html, "&lt;script&gt;"
    assert_includes html, "&lt;cite&gt;Album&lt;/cite&gt;"
    assert_includes html, "Heading"
    assert_not_includes html, "<h1"
    assert_not_includes html, "<img"
  end

  test "leaves an unsafe link as text" do
    html = InviteMessage.new(intro: "[click](javascript:alert(1))").intro_html(LINKS)

    assert_not_includes html, "<a"
  end

  test "rejects a link to an unknown placeholder" do
    message = show.invite_messages.new(intro: "[Yes][rsvp_yse]", about: "[me][]")

    assert_not message.valid?
    assert_equal [ "links to “rsvp_yse”, which isn’t a link name. Use rsvp_yes, rsvp_no or rsvp." ], message.errors[:intro]
    assert_equal [ "links to “me”, which isn’t a link name. Use rsvp_yes, rsvp_no or rsvp." ], message.errors[:about]
  end

  test "allows [name][] for a placeholder" do
    assert_predicate show.invite_messages.new(intro: "[rsvp_yes][]", about: "About"), :valid?
  end

  test "is locked once a batch using it is running or has sent something" do
    assert_not invite_message.locked?

    run = create_run(status: "running")
    assert_predicate invite_message, :locked?

    run.update!(status: "completed", sent_count: 1)
    assert_predicate invite_message, :locked?
  end

  test "is not locked by a batch that ended without sending anything" do
    create_run(status: "completed", sent_count: 0)

    assert_not invite_message.locked?
  end

  test "can be edited and deleted until it's locked" do
    assert invite_message.update(intro: "Fixed a typo")

    create_run(status: "completed", sent_count: 1)

    assert_not invite_message.update(intro: "Too late")
    assert_equal [ "Revision 1 has been sent, so it can’t be changed. Start a new revision instead." ], invite_message.errors.full_messages
    assert_equal "Fixed a typo", invite_message.reload.intro

    assert_not invite_message.destroy
    assert InviteMessage.exists?(invite_message.id)
  end

  test "a revision whose only batch sent nothing can be deleted" do
    run = create_run(status: "completed", sent_count: 0)

    assert invite_message.destroy
    assert_nil run.reload.invite_message_id
  end

  test "an unsent revision can be deleted, making the previous one current again" do
    second = new_revision

    assert second.destroy
    assert_equal invite_message, show.reload.invite_message
  end

  test "uses its revision number in URLs" do
    assert_equal "1", invite_message.to_param
  end

  test "deleting the admin who saved a revision keeps the revision" do
    admin = Admin.create!(email: "jane.smith@example.com", password: "correct horse battery staple")
    revision = shows(:upcoming).invite_messages.create!(intro: "Intro", about: "About", admin:)

    admin.destroy!

    assert_nil revision.reload.admin
  end
end
