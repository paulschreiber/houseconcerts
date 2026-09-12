require "test_helper"

module Madmin
  class OpensControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "index renders successfully" do
      get madmin_opens_path

      assert_response :success
    end

    test "show renders successfully" do
      get madmin_open_path(opens(:one))

      assert_response :success
    end

    test "edit redirects, since opens are read-only" do
      get edit_madmin_open_path(opens(:one))

      assert_redirected_to madmin_opens_path
    end

    test "new redirects, since opens are read-only" do
      get new_madmin_open_path

      assert_redirected_to madmin_opens_path
    end

    test "create redirects without creating a record, since opens are read-only" do
      assert_no_difference "Open.count" do
        post madmin_opens_path, params: { open: { email: "new@example.com" } }
      end

      assert_redirected_to madmin_opens_path
    end

    test "update redirects without changing the record, since opens are read-only" do
      open = opens(:one)

      patch madmin_open_path(open), params: { open: { email: "changed@example.com" } }

      assert_redirected_to madmin_opens_path
      assert_nil open.reload.email
    end

    test "destroy redirects without destroying the record, since opens are read-only" do
      assert_no_difference "Open.count" do
        delete madmin_open_path(opens(:one))
      end

      assert_redirected_to madmin_opens_path
    end
  end
end
