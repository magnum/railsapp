# frozen_string_literal: true

require "test_helper"

class BookmarksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(password: "password1", password_confirmation: "password1")
  end

  test "admin toggles a static page bookmark" do
    @user.add_role(:admin)
    sign_in_as(@user)
    page = static_pages(:privacy)

    assert_difference -> { @user.bookmarks.count }, 1 do
      post toggle_bookmark_path, params: { bookmarkable_type: "StaticPage", bookmarkable_id: page.id }, as: :json
    end

    assert_response :success
    assert_equal true, response.parsed_body["starred"]
    assert_equal page, @user.bookmarks.last.bookmarkable

    assert_difference -> { @user.bookmarks.count }, -1 do
      post toggle_bookmark_path, params: { bookmarkable_type: "StaticPage", bookmarkable_id: page.id }, as: :json
    end

    assert_response :success
    assert_equal false, response.parsed_body["starred"]
  end

  test "rejects an unknown bookmarkable type" do
    @user.add_role(:admin)
    sign_in_as(@user)

    post toggle_bookmark_path, params: { bookmarkable_type: "User", bookmarkable_id: @user.id }, as: :json

    assert_response :not_found
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

    get admin_root_path

    assert_response :success
    assert_select "select#workspace_id option[selected][value=?]", other.id.to_s
    assert_select "button.bookmark-link.is-starred[data-bookmark-link-type-value=Workspace][data-bookmark-link-id-value=?]", other.id.to_s

    post select_workspace_path, params: { workspace_id: workspaces(:one).id }
    get admin_root_path

    assert_select "select#workspace_id option[selected][value=?]", workspaces(:one).id.to_s
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password1" }
  end
end
