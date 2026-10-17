# frozen_string_literal: true

require "test_helper"

class Admin::BookmarksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(password: "password1", password_confirmation: "password1")
    @admin.add_role(:admin)
    @bookmark = Bookmark.create!(user: @admin, bookmarkable: static_pages(:privacy))
    sign_in_as(@admin)
  end

  test "admin lists bookmarks" do
    get admin_bookmarks_path

    assert_response :success
    assert_select "a[href=?]", admin_bookmark_path(@bookmark)
  end

  test "admin user page lists bookmarks" do
    get admin_user_path(@admin)

    assert_response :success
    assert_select "a[href*=?]", "/admin/bookmarks/#{@bookmark.id}"
  end

  test "admin updates and deletes another user's bookmark" do
    owner = users(:two)
    bookmark = Bookmark.create!(user: owner, bookmarkable: static_pages(:privacy))

    patch admin_bookmark_path(bookmark), params: {
      bookmark: {
        user_id: owner.id,
        bookmarkable: { type: "Administrate::Field::Polymorphic", value: static_pages(:terms).to_global_id.to_s }
      }
    }

    assert_redirected_to admin_bookmark_path(bookmark)
    assert_equal static_pages(:terms), bookmark.reload.bookmarkable

    assert_difference("Bookmark.count", -1) do
      delete admin_bookmark_path(bookmark)
    end
    assert_redirected_to admin_bookmarks_path
  end

  test "user lists, updates, and deletes only their own bookmarks" do
    owner = users(:two)
    owner.update!(password: "password1", password_confirmation: "password1")
    own = Bookmark.create!(user: owner, bookmarkable: static_pages(:privacy))
    delete sign_out_path
    sign_in_as(owner)

    get admin_bookmarks_path

    assert_response :success
    assert_select "a[href=?]", admin_bookmark_path(own)
    assert_select "a[href=?]", admin_bookmark_path(@bookmark), count: 0

    patch admin_bookmark_path(own), params: {
      bookmark: {
        user_id: @admin.id,
        bookmarkable: { type: "Administrate::Field::Polymorphic", value: static_pages(:terms).to_global_id.to_s }
      }
    }

    assert_redirected_to admin_bookmark_path(own)
    own.reload
    assert_equal owner, own.user
    assert_equal static_pages(:terms), own.bookmarkable

    get edit_admin_bookmark_path(@bookmark)
    assert_response :not_found

    assert_no_difference("Bookmark.count") do
      delete admin_bookmark_path(@bookmark)
    end
    assert_response :not_found

    assert_difference("Bookmark.count", -1) do
      delete admin_bookmark_path(own)
    end
    assert_redirected_to admin_bookmarks_path
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password1" }
  end
end
