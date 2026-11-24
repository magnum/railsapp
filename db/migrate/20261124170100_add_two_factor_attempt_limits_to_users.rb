class AddTwoFactorAttemptLimitsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_failed_attempts, :integer, null: false, default: 0
    add_column :users, :otp_locked_until, :datetime
  end
end