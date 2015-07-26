class AddRSVPUniqid < ActiveRecord::Migration
  def change
    add_column :rsvps, :uniqid, :string, after: :id
    add_index :rsvps, :uniqid, unique: true

    RSVP.where(uniqid: nil).each do |rsvp|
      rsvp.update_attribute(:uniqid, rand(2821109907456).to_s(36))
    end

    RSVP.update_all('response = LOWER(response)')
  end
end
