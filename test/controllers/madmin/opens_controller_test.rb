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
  end
end
