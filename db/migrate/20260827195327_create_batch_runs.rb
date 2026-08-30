class CreateBatchRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :batch_runs do |t|
      t.references :show, null: false, foreign_key: true
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.integer :total_count, null: false, default: 0
      t.integer :sent_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    create_table :batch_run_items do |t|
      t.references :batch_run, null: false, foreign_key: true
      t.references :recipient, polymorphic: true, null: false
      t.integer :status, null: false, default: 0
      t.string :error_message
      t.datetime :sent_at

      t.timestamps
    end
  end
end
