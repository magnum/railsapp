class CreateUserIdentities < ActiveRecord::Migration[8.1]
  def up
    create_table :user_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.timestamps
    end

    add_index :user_identities, [ :provider, :uid ], unique: true

    execute <<~SQL.squish
      INSERT INTO user_identities (user_id, provider, uid, created_at, updated_at)
      SELECT id, provider, uid, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users
      WHERE provider IS NOT NULL AND uid IS NOT NULL
    SQL
  end

  def down
    drop_table :user_identities
  end
end