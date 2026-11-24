class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_secret_ciphertext, :text
    add_column :users, :otp_pending_secret_ciphertext, :text
    add_column :users, :otp_enabled_at, :datetime
    add_column :users, :otp_last_used_at, :datetime

    create_table :user_backup_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.timestamps
    end

    add_index :user_backup_codes, [ :user_id, :code_digest ], unique: true
  end
end