# frozen_string_literal: true

require "test_helper"

class MenuNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(password: "password1", password_confirmation: "password1")
    @editor = users(:two)
    @editor.update!(password: "password1", password_confirmation: "password1")
  end

  test "signed out header keeps locale before sign in and hides the menu tree" do
    get root_path

    assert_response :success
    assert_select "label[for=locale]", count: 0
    assert_select "button[aria-controls=app-nav] .off-canvas-icon--open"
    assert_select "button[aria-controls=app-nav] .off-canvas-icon--close"
    nav = css_select("nav#app-nav").first.to_html
    assert nav.index("locale-select") < nav.index(I18n.t("sessions.sign_in"))
    assert_select "nav#app-nav", text: /#{Regexp.escape(I18n.t("menu_items.menu"))}/, count: 0
    assert_select "header a[href=?]", root_path
  end

  test "logo points at the menu item marked as home" do
    menu_items(:pages).update!(is_home: true)

    get root_path

    assert_select "header a[href=?]", static_pages_path
  end

  test "admin header shows bookmarked items between the locale and the tools tree" do
    @user.add_role(:admin)
    Bookmark.create!(user: @user, bookmarkable: menu_items(:users))
    sign_in_as(@user)

    get root_path

    assert_response :success
    nav = css_select("nav#app-nav").first.to_html
    pages = I18n.t("static_pages.pages_link")
    users = I18n.t("users.index.title")
    menu = I18n.t("menu_items.menu")
    assert nav.index("locale-select") < nav.index(">#{users}<")
    assert nav.index(">#{users}<") < nav.index(">#{menu}<")
    assert nav.index(">#{menu}<") < nav.index(@user.email)
    assert nav.index(">Admin<") < nav.index(">#{I18n.t("menu_items.workspaces")}<")
    assert nav.index(">#{I18n.t("menu_items.workspaces")}<") < nav.index(">#{workspaces(:one).name}<")
    assert nav.index(">#{workspaces(:one).name}<") < nav.index("<hr")
    assert nav.index("<hr") < nav.index(">#{pages}<")
    assert_select "a[href=?]", users_path, text: users
    assert_select "a[href=?]", static_pages_path, text: pages
    assert_select "a[href=?]", admin_root_path, text: "Admin"
    assert_select "a[href=?]", users_path, text: I18n.t("users.index.title")
    assert_select "span.menu-tree__label", text: menu
    assert_select "li.menu-tree__item.has-children > .menu-tree__row", text: /#{Regexp.escape(menu)}/
    assert_select ".menu-shortcuts .bookmark-link", count: 0
    assert_select ".menu-tree__item.is-root > .menu-tree__row .bookmark-link", count: 0
    assert_select ".menu-tree .menu-tree .bookmark-link", minimum: 1
  end

  test "editor header shows only pages under tools" do
    @editor.add_role(:editor)
    sign_in_as(@editor)

    get root_path

    assert_response :success
    assert_select "a", text: I18n.t("static_pages.pages_link")
    assert_select "a", text: I18n.t("users.index.title"), count: 0
    assert_select "a", text: "Admin", count: 0
    assert_select ".menu-shortcuts .bookmark-link", count: 0
    assert_select "button.bookmark-link[data-bookmark-link-type-value=MenuItem]", minimum: 1
    assert_select "button.bookmark-link[data-bookmark-link-type-value=Workspace]", minimum: 1
  end

  test "admin toggles a menu item bookmark" do
    @user.add_role(:admin)
    sign_in_as(@user)

    assert_difference -> { @user.bookmarks.count }, 1 do
      post toggle_bookmark_path, params: { bookmarkable_type: "MenuItem", bookmarkable_id: menu_items(:pages).id }, as: :json
    end

    assert_response :success
    assert_equal true, response.parsed_body["starred"]
    assert_equal menu_items(:pages), @user.bookmarks.last.bookmarkable
  end

  test "a workspace bookmark replaces the other workspace bookmarks" do
    @user.add_role(:admin)
    other = Workspace.create!(user: users(:two), name: "Other")
    Bookmark.create!(user: @user, bookmarkable: workspaces(:one))
    sign_in_as(@user)

    assert_no_difference -> { @user.bookmarks.where(bookmarkable_type: "Workspace").count } do
      post toggle_bookmark_path, params: { bookmarkable_type: "Workspace", bookmarkable_id: other.id }, as: :json
    end

    assert_response :success
    assert_equal [ other ], @user.bookmarks.where(bookmarkable_type: "Workspace").map(&:bookmarkable)
  end

  test "bookmarked workspace is current until a workspace is chosen" do
    @user.add_role(:admin)
    other = Workspace.create!(user: users(:two), name: "Other")
    Bookmark.create!(user: @user, bookmarkable: other)
    sign_in_as(@user)

    get root_path

    assert_response :success
    assert_select "button[aria-current=true]", text: other.name

    post select_workspace_path, params: { workspace_id: workspaces(:one).id }
    get root_path

    assert_select "button[aria-current=true]", text: workspaces(:one).name
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password1" }
  end
end
