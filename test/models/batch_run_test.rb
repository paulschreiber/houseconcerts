require "test_helper"

class BatchRunTest < ActiveSupport::TestCase
  test "processed_count sums sent and failed counts" do
    batch_run = BatchRun.new(sent_count: 2, failed_count: 1)

    assert_equal 3, batch_run.processed_count
  end

  test "belongs to a show and has many batch_run_items" do
    batch_run = BatchRun.create!(show: shows(:upcoming), kind: "invite", total_count: 1)
    item = batch_run.batch_run_items.create!(recipient: people(:one))

    assert_equal shows(:upcoming), batch_run.show
    assert_includes batch_run.batch_run_items, item
  end
end
