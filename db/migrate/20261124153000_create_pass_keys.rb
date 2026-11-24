class CreatePassKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :webauthn_id, :string
    add_index :users, :webauthn_id, unique: true, where: "webauthn_id IS NOT NULL"

    create_table :pass_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :pass_keys, :external_id, unique: true
  end
end