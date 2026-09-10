# frozen_string_literal: true

class CreateAccountsAndAddAccountId < ActiveRecord::Migration[8.1]
  class MigrationAccount < ApplicationRecord
    self.table_name = "accounts"
  end

  ACCOUNTABLE_TABLES = %w[users api_keys plans invitations webhooks static_pages].freeze

  def up
    create_table :accounts do |t|
      t.string :name, null: false
      t.timestamps
    end

    account = MigrationAccount.create!(name: "RailsApp")

    ACCOUNTABLE_TABLES.each do |table|
      add_reference table, :account, foreign_key: true
      execute "UPDATE #{quote_table_name(table)} SET account_id = #{account.id} WHERE account_id IS NULL"
      change_column_null table, :account_id, false
    end
  end

  def down
    ACCOUNTABLE_TABLES.each do |table|
      remove_reference table, :account, foreign_key: true
    end
    drop_table :accounts
  end
end
