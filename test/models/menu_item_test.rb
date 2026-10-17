# frozen_string_literal: true

require "test_helper"

class MenuItemTest < ActiveSupport::TestCase
  test "nests the default menu" do
    menu = menu_items(:menu)

    assert_nil menu.link
    assert_equal [ "Pages", "Admin", "Users" ], menu.children.map(&:name)
    assert menu.children.all? { |item| item.parent == menu }
  end

  test "ensure_defaults is idempotent" do
    assert_no_difference("MenuItem.count") do
      MenuItem.ensure_defaults!
    end

    assert_equal [ "Pages", "Admin", "Users" ], menu_items(:menu).reload.children.map(&:name)
  end

  test "shows pages to editors and the other tools to admins" do
    editor = users(:two)
    editor.add_role(:editor)
    admin = users(:one)
    admin.add_role(:admin)
    grouped = MenuItem.where(active: true).order(:ord, :id).group_by(&:parent_id)

    assert menu_items(:pages).visible_to?(editor, grouped)
    assert_not menu_items(:admin).visible_to?(editor, grouped)
    assert menu_items(:menu).visible_to?(editor, grouped)
    assert menu_items(:users).visible_to?(admin, grouped)
    assert_not menu_items(:menu).visible_to?(nil, grouped)

    member = users(:two)
    member.roles.destroy_all
    assert_not menu_items(:pages).visible_to?(member, grouped)
    assert_not menu_items(:users).visible_to?(member, grouped)
    assert menu_items(:menu).visible_to?(member, grouped)
  end

  test "keeping one home clears the flag on every other menu item" do
    menu_items(:pages).update!(is_home: true)
    menu_items(:users).update!(is_home: true)

    assert menu_items(:users).reload.is_home?
    assert_not menu_items(:pages).reload.is_home?
    assert_equal 1, MenuItem.where(is_home: true).count
  end

  test "accepts bookmarks through the concern" do
    bookmark = Bookmark.create!(user: users(:one), bookmarkable: menu_items(:pages))

    assert_equal [ bookmark ], menu_items(:pages).bookmarks
    assert_includes StaticPage.included_modules, Bookmarkable
    assert_not static_pages(:privacy).bookmarkable_single?
    assert_not menu_items(:menu).bookmarkable_single?
    assert workspaces(:one).bookmarkable_single?
  end
end
