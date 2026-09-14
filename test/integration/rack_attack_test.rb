require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    # The test environment's null_store cache can't hold rack-attack's
    # throttle counters across requests, so swap in a real cache for the
    # duration of this test.
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.cache.store = @original_store
  end

  test "throttles repeated requests to a uniqid-keyed path from the same ip" do
    20.times { get open_tracking_path(tag: "test:invite", uniqid: "nonexistent") }

    assert_response :success

    get open_tracking_path(tag: "test:invite", uniqid: "nonexistent")

    assert_response :too_many_requests
  end

  test "does not throttle a path that isn't uniqid-keyed" do
    25.times { get root_path }

    assert_response :success
  end
end
