# frozen_string_literal: true

class AddNameToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :name, :string

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE workspaces
          SET name = 'My Workspace'
          WHERE name IS NULL OR name = ''
        SQL
        change_column_null :workspaces, :name, false
      end

      dir.down do
        change_column_null :workspaces, :name, true
      end
    end
  end
end
