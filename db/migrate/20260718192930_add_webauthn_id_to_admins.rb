class AddWebauthnIdToAdmins < ActiveRecord::Migration[8.1]
  def change
    change_table :admins, bulk: true do |t|
      t.string :webauthn_id
      t.index :webauthn_id, unique: true
    end
  end
end
