require "test_helper"

module Madmin
  class AdminsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "index lists admins by email" do
      get madmin_admins_path

      assert_response :success
      assert_operator response.body.index(admins(:one).email), :<, response.body.index(admins(:two).email)
    end

    test "show lists the admin's passkeys and never the password" do
      admins(:two).passkeys.create!(external_id: "abc", public_key: "key", name: "Work laptop", sign_count: 0)

      get madmin_admin_path(admins(:two))

      assert_response :success
      assert_select "*", text: "Work laptop"
      assert_no_match(/encrypted_password|reset_password_token/i, response.body)
    end

    test "the form only has the email" do
      get new_madmin_admin_path

      assert_response :success
      assert_select "form input[name^='admin[']:not([type=hidden])", count: 1
      assert_select "input[name='admin[email]']"
    end

    test "create adds an admin and emails them a link to set their password" do
      assert_difference "Admin.count", 1 do
        assert_enqueued_email_with AdminMailer, :welcome, args: ->(args) { args.first.email == "jane.smith@example.com" } do
          post madmin_admins_path, params: { admin: { email: "jane.smith@example.com" } }
        end
      end

      admin = Admin.find_by!(email: "jane.smith@example.com")
      assert_redirected_to madmin_admin_path(admin)
      assert_predicate admin.reset_password_token, :present?
    end

    test "create ignores a password in the params" do
      post madmin_admins_path, params: { admin: { email: "jane.smith@example.com", password: "chosen by someone else" } }

      assert_not Admin.find_by!(email: "jane.smith@example.com").valid_password?("chosen by someone else")
    end

    test "create with an email that's taken renders new" do
      assert_no_difference "Admin.count" do
        assert_no_enqueued_emails do
          post madmin_admins_path, params: { admin: { email: admins(:two).email } }
        end
      end

      assert_response :unprocessable_content
    end

    test "update changes the email" do
      patch madmin_admin_path(admins(:two)), params: { admin: { email: "jane.smith@example.com" } }

      assert_redirected_to madmin_admin_path(admins(:two))
      assert_equal "jane.smith@example.com", admins(:two).reload.email
    end

    test "destroy deletes another admin" do
      assert_difference "Admin.count", -1 do
        delete madmin_admin_path(admins(:two))
      end

      assert_redirected_to madmin_admins_path
    end

    test "destroy refuses to delete your own account" do
      assert_no_difference "Admin.count" do
        delete madmin_admin_path(admins(:one))
      end

      assert_redirected_to madmin_admins_path
      assert_equal "You can’t delete your own account.", flash[:alert]
    end
  end
end
