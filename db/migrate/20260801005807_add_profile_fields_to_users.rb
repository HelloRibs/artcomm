class AddProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users, bulk: true do |t|
      # Public handle, used as the first segment of every public URL.
      t.string :username, null: false
      # What the public sees. Falls back to the username when blank.
      t.string :display_name
      t.text   :bio
      # Digits only, in E.164 order (country code first) so it can be dropped
      # straight into a wa.me link.
      t.string :whatsapp_phone
    end

    add_index :users, :username, unique: true
  end
end
