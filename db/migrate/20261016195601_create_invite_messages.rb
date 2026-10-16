class CreateInviteMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :invite_messages do |t|
      t.references :show, null: false, foreign_key: true
      t.integer :revision, null: false
      t.text :intro, null: false
      t.text :about, null: false
      t.references :admin, foreign_key: true
      t.string :source_commit
      t.timestamps
    end
    add_index :invite_messages, %i[show_id revision], unique: true
    add_index :invite_messages, :source_commit, unique: true

    add_reference :batch_runs, :invite_message, foreign_key: true
  end
end
