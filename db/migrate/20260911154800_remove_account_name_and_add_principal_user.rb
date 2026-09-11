# frozen_string_literal: true

class RemoveAccountNameAndAddPrincipalUser < ActiveRecord::Migration[8.1]
  def change
    add_reference :accounts, :user, foreign_key: true, index: { unique: true }
    change_column_null :users, :account_id, true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE accounts
          SET user_id = sub.id
          FROM (
            SELECT DISTINCT ON (account_id) id, account_id
            FROM users
            WHERE account_id IS NOT NULL
            ORDER BY account_id, id
          ) sub
          WHERE accounts.id = sub.account_id
            AND accounts.user_id IS NULL
        SQL

        nulls = select_value("SELECT COUNT(*) FROM accounts WHERE user_id IS NULL").to_i
        change_column_null :accounts, :user_id, false if nulls.zero?

        remove_column :accounts, :name
      end

      dir.down do
        add_column :accounts, :name, :string
        execute <<~SQL
          UPDATE accounts
          SET name = COALESCE(
            (SELECT email FROM users WHERE users.id = accounts.user_id),
            'Account ' || accounts.id::text
          )
        SQL
        change_column_null :accounts, :name, false
        change_column_null :accounts, :user_id, true
      end
    end
  end
end
