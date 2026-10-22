require "test_helper"

module Madmin
  class InviteMessagesControllerTest < ActionDispatch::IntegrationTest
    include BatchTestHelpers
    include ActionMailer::TestHelper

    setup do
      sign_in admins(:one)
    end

    def invite_message
      invite_messages(:upcoming)
    end

    test "index lists the show's revisions" do
      show.invite_messages.create!(intro: "Second", about: "Second")

      get madmin_show_invite_messages_path(show)

      assert_response :success
      assert_select "td a", text: "Revision 2"
      assert_select "td a", text: "Revision 1"
      assert_select "a", text: "Back", count: 0
    end

    test "the invite pages are headed title / the show, linked like Madmin's record pages" do
      {
        madmin_show_invite_messages_path(show) => "Invite History",
        new_madmin_show_invite_message_path(show) => "New Invite Revision",
        madmin_show_invite_message_path(show, invite_message) => "Invite, Revision 1",
        edit_madmin_show_invite_message_path(show, invite_message) => "Invite, Revision 1"
      }.each do |path, title|
        get path

        assert_select "h1", text: "#{title} / #{show.dated_name}"
        assert_select "h1 a[href=?]", madmin_show_path(show), text: show.dated_name
      end
    end

    test "index has an Edit button only for unsent revisions" do
      create_run(status: "completed", sent_count: 1)
      second = show.invite_messages.create!(intro: "Second", about: "Second")

      get madmin_show_invite_messages_path(show)

      assert_select "td.actions a.btn[href=?]", edit_madmin_show_invite_message_path(show, second), text: "Edit"
      assert_select "td.actions a[href=?]", edit_madmin_show_invite_message_path(show, invite_message), count: 0
      assert_select "td.actions form", count: 0
    end

    test "once the show has happened, its New and Edit buttons are disabled, and Delete stays" do
      past = shows(:past)
      reason = InviteMessage.closed_reason(past)

      get madmin_show_invite_messages_path(past)
      assert_select "button[disabled][title=?]", reason, text: "Write Invite"
      assert_select "a[href=?]", new_madmin_show_invite_message_path(past), count: 0

      draft = past.invite_messages.create!(intro: "Draft", about: "Draft")

      get madmin_show_invite_message_path(past, draft)
      assert_select "button[disabled][title=?]", reason, text: "Edit"
      assert_select "button[disabled][title=?]", reason, text: "New Revision"
      assert_select "a[href=?]", edit_madmin_show_invite_message_path(past, draft), count: 0
      assert_select "button", text: "Delete"

      get madmin_show_path(past)
      assert_select ".actions-row button[disabled]", text: "Edit Invite"
    end

    test "once the show has happened, new, create, edit and update refuse, and delete still works" do
      past = shows(:past)
      draft = past.invite_messages.create!(intro: "Draft", about: "Draft")
      history = madmin_show_invite_messages_path(past)
      alert = "#{past.name} has already happened, so its invite can’t be changed."

      get new_madmin_show_invite_message_path(past)
      assert_redirected_to history
      assert_equal alert, flash[:alert]

      assert_no_difference("InviteMessage.count") do
        post madmin_show_invite_messages_path(past), params: { invite_message: { intro: "Late", about: "Late" } }
      end
      assert_redirected_to history
      assert_equal alert, flash[:alert]

      get edit_madmin_show_invite_message_path(past, draft)
      assert_redirected_to history
      assert_equal alert, flash[:alert]

      patch madmin_show_invite_message_path(past, draft), params: { invite_message: { intro: "Changed" } }
      assert_redirected_to history
      assert_equal alert, flash[:alert]
      assert_equal "Draft", draft.reload.intro

      delete madmin_show_invite_message_path(past, draft)
      assert_not InviteMessage.exists?(draft.id)
    end

    test "new starts from the current revision's text" do
      get new_madmin_show_invite_message_path(show)

      assert_response :success
      assert_select "textarea[name='invite_message[intro]']", text: invite_message.intro
      assert_select "iframe[name='invite-preview']"
    end

    test "new has Create Invite and a Cancel link back to the history, not Back or Delete" do
      get new_madmin_show_invite_message_path(show)

      assert_select ".form-secondary-actions button[type=submit][form=invite-editor-form]", text: "Create Invite"
      assert_select ".form-secondary-actions a[href=?]", madmin_show_invite_messages_path(show), text: "Cancel"
      assert_select ".form-secondary-actions button", text: "Delete", count: 0
      assert_select "a", text: "Back", count: 0
    end

    test "edit has Update Invite, Send Test, Delete and a Cancel link back to the revision, not Back" do
      get edit_madmin_show_invite_message_path(show, invite_message)

      assert_select ".form-secondary-actions button[type=submit][form=invite-editor-form]", text: "Update Invite"
      assert_select "[data-controller='invite-preview'] .header .actions form[action=?] button[data-invite-preview-target=testButton]", send_test_madmin_show_invite_message_path(show, invite_message), text: "Send Test"
      assert_select ".form-secondary-actions button", text: "Send Test", count: 0
      assert_select ".form-secondary-actions form[action=?] button.btn-danger", madmin_show_invite_message_path(show, invite_message), text: "Delete"
      assert_select ".form-secondary-actions a[href=?]", madmin_show_invite_message_path(show, invite_message), text: "Cancel"
      assert_select "a", text: "Back", count: 0
    end

    test "create saves the next revision, by the signed-in admin" do
      post madmin_show_invite_messages_path(show), params: { invite_message: { intro: "New intro", about: "New bio" } }

      revision = show.invite_message
      assert_equal 2, revision.revision
      assert_equal admins(:one), revision.admin
      assert_redirected_to edit_madmin_show_invite_message_path(show, revision)
      assert_equal "Saved revision 2.", flash[:notice]
    end

    test "create re-renders the editor with the errors" do
      post madmin_show_invite_messages_path(show), params: { invite_message: { intro: "[Yes][rsvp_yse]", about: "" } }

      assert_response :unprocessable_content
      assert_select ".alert-danger li", text: /rsvp_yse/
      assert_equal 1, show.invite_messages.count
    end

    test "update saves edits to an unsent revision" do
      patch madmin_show_invite_message_path(show, invite_message), params: { invite_message: { intro: "Fixed", about: "Fixed bio" } }

      assert_redirected_to edit_madmin_show_invite_message_path(show, invite_message)
      assert_equal "Fixed", invite_message.reload.intro
    end

    test "a failed save disables Send Test, since the form no longer shows the saved text" do
      patch madmin_show_invite_message_path(show, invite_message), params: { invite_message: { intro: "[Yes][rsvp_yse]", about: "Bio" } }

      assert_response :unprocessable_content
      assert_select "button[disabled]", text: "Send Test"
    end

    test "a sent revision can't be edited" do
      create_run(status: "completed", sent_count: 1)

      get edit_madmin_show_invite_message_path(show, invite_message)
      assert_redirected_to madmin_show_invite_message_path(show, invite_message)

      patch madmin_show_invite_message_path(show, invite_message), params: { invite_message: { intro: "Too late", about: "Too late" } }
      assert_redirected_to madmin_show_invite_message_path(show, invite_message)
      assert_equal "Revision 1 has been sent, so it can’t be changed. Start a new revision instead.", flash[:alert]
      assert_not_equal "Too late", invite_message.reload.intro
    end

    test "show displays a revision read-only, with Edit and Delete only until it's sent" do
      get madmin_show_invite_message_path(show, invite_message)
      assert_select "a.btn-secondary", text: "Edit"
      assert_select "button", text: "Delete"
      assert_select "button[data-turbo-confirm=?]", "Delete invite revision 1 for #{show.dated_name}?"
      assert_select "a", text: "Back", count: 0
      assert_select "iframe[src='#{preview_madmin_show_invite_message_path(show, invite_message)}']"

      create_run(status: "completed", sent_count: 1)

      get madmin_show_invite_message_path(show, invite_message)
      assert_select "a", text: "Edit", count: 0
      assert_select "button", text: "Delete", count: 0
      assert_select "a", text: "New Revision"
    end

    test "destroy deletes an unsent revision" do
      second = show.invite_messages.create!(intro: "Second", about: "Second")

      delete madmin_show_invite_message_path(show, second)

      assert_redirected_to madmin_show_invite_messages_path(show)
      assert_not InviteMessage.exists?(second.id)
    end

    test "destroy keeps a sent revision" do
      create_run(status: "completed", sent_count: 1)

      delete madmin_show_invite_message_path(show, invite_message)

      assert_redirected_to madmin_show_invite_message_path(show, invite_message)
      assert InviteMessage.exists?(invite_message.id)
    end

    test "preview renders unsaved text, framed by the editor's own page" do
      post preview_madmin_show_invite_messages_path(show), params: { invite_message: { intro: "Draft **intro**", about: "Draft bio" } }

      assert_response :success
      assert_includes response.body, "Draft <strong>intro</strong>"
      assert_includes response.headers["Content-Security-Policy"], "frame-ancestors 'self'"
      assert_includes response.headers["Content-Security-Policy"], "sandbox"
    end

    test "preview renders the edit form's unsaved text" do
      patch preview_madmin_show_invite_messages_path(show), params: { invite_message: { intro: "Edited", about: "Edited bio" } }

      assert_includes response.body, "Edited"
    end

    test "the editor form's CSRF token is accepted by the preview" do
      ActionController::Base.allow_forgery_protection = true

      get new_madmin_show_invite_message_path(show)
      token = css_select("form.invite-editor-form input[name='authenticity_token']").first["value"]
      post preview_madmin_show_invite_messages_path(show), params: { authenticity_token: token, invite_message: { intro: "Draft", about: "Draft bio" } }

      assert_response :success
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    test "preview renders a saved revision" do
      get preview_madmin_show_invite_message_path(show, invite_message)

      assert_includes response.body, "Next up: a <strong>test</strong> show."
    end

    test "send_test sends the revision to the signed-in admin's mailing-list entry" do
      person = Person.create!(first_name: "Jane", last_name: "Smith", email: admins(:one).email, status: "active")

      assert_enqueued_email_with InvitesMailer, :invite, params: { person:, show:, email_type: "test", invite_message: } do
        post send_test_madmin_show_invite_message_path(show, invite_message)
      end
      assert_equal "Sent a test of revision 1 to #{person.email}.", flash[:notice]
      assert_not invite_message.locked?
    end

    test "send_test asks an admin who isn't on the mailing list to add themselves" do
      assert_no_enqueued_emails do
        post send_test_madmin_show_invite_message_path(show, invite_message)
      end

      assert_equal "Add yourself (#{admins(:one).email}) to the mailing list to get test sends.", flash[:alert]
    end

    test "the show page links to writing, editing or starting a new revision of the invite" do
      get madmin_show_path(shows(:sold_out))
      assert_select "a[href='#{new_madmin_show_invite_message_path(shows(:sold_out))}']", text: "Write Invite"

      get madmin_show_path(show)
      assert_select "a[href='#{edit_madmin_show_invite_message_path(show, invite_message)}']", text: "Edit Invite"
      assert_select "a", text: "Invite History"

      create_run(status: "completed", sent_count: 1)
      get madmin_show_path(show)
      assert_select "a[href='#{new_madmin_show_invite_message_path(show)}']", text: "New Invite Revision"
    end
  end
end
