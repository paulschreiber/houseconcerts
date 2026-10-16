class CreateInviteMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :invite_messages do |t|
      t.references :show, null: false, foreign_key: true, index: false
      t.integer :revision, null: false
      t.text :intro, null: false
      t.text :about, null: false
      t.references :admin, foreign_key: true
      t.timestamps
    end
    add_index :invite_messages, %i[show_id revision], unique: true

    add_reference :batch_runs, :invite_message, foreign_key: true
  end
end
