class AddAutoRemindToShowsAndBatchRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :auto_remind_attempted_at, :datetime
    add_column :shows, :rescheduled_at, :datetime
    add_column :batch_runs, :automatic, :boolean, default: false, null: false
  end
end
