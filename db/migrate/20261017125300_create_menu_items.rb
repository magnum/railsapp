# frozen_string_literal: true

class CreateMenuItems < ActiveRecord::Migration[8.1]
  def up
    create_table :menu_items do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.string :link
      t.integer :ord, null: false, default: 0
      t.boolean :is_home, null: false, default: false
      t.references :parent, foreign_key: { to_table: :menu_items }
      t.integer :lft, null: false
      t.integer :rgt, null: false
      t.integer :depth, null: false, default: 0
      t.timestamps
    end

    add_index :menu_items, :lft
    add_index :menu_items, :rgt
    add_index :menu_items, [ :parent_id, :ord ]
    add_index :menu_items, :is_home, unique: true, where: "is_home = true"

    MenuItem.reset_column_information
    MenuItem.ensure_defaults!
  end

  def down
    drop_table :menu_items
  end
end
