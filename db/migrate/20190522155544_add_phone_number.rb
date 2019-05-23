class AddPhoneNumber < ActiveRecord::Migration
  def change
    add_column :rsvps, :phone_number, :string, after: :email
    add_column :people, :phone_number, :string, after: :email
  end
end
