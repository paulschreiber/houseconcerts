require "test_helper"

class BatchRunItemTest < ActiveSupport::TestCase
  include BatchTestHelpers

  test "belongs to a batch_run and a polymorphic recipient" do
    batch_run = create_run(status: "pending")
    item = batch_run.batch_run_items.create!(recipient: people(:one))

    assert_equal batch_run, item.batch_run
    assert_equal people(:one), item.recipient
    assert item.pending?
  end

  test "status defaults to pending" do
    batch_run = create_run(kind: "remind", status: "pending")
    item = batch_run.batch_run_items.create!(recipient: rsvps(:one))

    assert_equal "pending", item.status
  end
end
