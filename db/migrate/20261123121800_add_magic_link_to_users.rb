class AddMagicLinkToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :magic_link_digest, :string
    add_column :users, :magic_link_sent_at, :datetime
    add_index :users, :magic_link_digest, unique: true, where: "magic_link_digest IS NOT NULL"
  end
end