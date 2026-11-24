require "test_helper"

module SiteHealth
  class SesCredentialsTest < ActiveSupport::TestCase
    Credentials = Struct.new(:amazon)
    Amazon = Struct.new(:username, :password, :server)

    test "has no problems when all credentials are present" do
      in_production do
        assert_empty SesCredentials.problems(Credentials.new(Amazon.new("user", "pass", "smtp.example.com")))
      end
    end

    test "lists the missing credentials" do
      in_production do
        assert_equal [ "Missing credentials: amazon.password, amazon.server." ],
                     SesCredentials.problems(Credentials.new(Amazon.new("user", nil, "")))
      end
    end

    test "requires all of them when there is no Amazon section" do
      in_production do
        assert_equal [ "Missing credentials: amazon.username, amazon.password, amazon.server." ], SesCredentials.problems(Credentials.new(nil))
      end
    end

    test "checks nothing outside production" do
      assert_empty SesCredentials.problems(Credentials.new(nil))
    end
  end
end
