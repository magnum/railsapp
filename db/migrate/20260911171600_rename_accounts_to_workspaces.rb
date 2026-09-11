# frozen_string_literal: true

class RenameAccountsToWorkspaces < ActiveRecord::Migration[8.1]
  WORKSPACEABLE_TABLES = %w[users api_keys plans invitations webhooks static_pages].freeze

  def change
    WORKSPACEABLE_TABLES.each do |table|
      remove_foreign_key table, column: :account_id
    end

    rename_table :accounts, :workspaces

    if index_name_exists?(:workspaces, "index_accounts_on_user_id")
      rename_index :workspaces, "index_accounts_on_user_id", "index_workspaces_on_user_id"
    end

    WORKSPACEABLE_TABLES.each do |table|
      rename_column table, :account_id, :workspace_id
      if index_name_exists?(table, "index_#{table}_on_account_id")
        rename_index table, "index_#{table}_on_account_id", "index_#{table}_on_workspace_id"
      end
      add_foreign_key table, :workspaces
    end
  end
end
