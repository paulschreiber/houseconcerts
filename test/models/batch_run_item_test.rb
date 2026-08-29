require "test_helper"

class BatchRunItemTest < ActiveSupport::TestCase
  test "belongs to a batch_run and a polymorphic recipient" do
    batch_run = BatchRun.create!(show: shows(:upcoming), kind: "invite", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: people(:one))

    assert_equal batch_run, item.batch_run
    assert_equal people(:one), item.recipient
    assert item.pending?
  end

  test "status defaults to pending" do
    batch_run = BatchRun.create!(show: shows(:upcoming), kind: "remind", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: rsvps(:one))

    assert_equal "pending", item.status
  end
end
