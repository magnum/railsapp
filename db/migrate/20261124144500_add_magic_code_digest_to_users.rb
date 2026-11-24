class AddMagicCodeDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :magic_code_digest, :string
    add_index :users, :magic_code_digest, unique: true, where: "magic_code_digest IS NOT NULL"
  end
end