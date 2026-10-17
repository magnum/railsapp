# frozen_string_literal: true

require "test_helper"

class BookmarkTest < ActiveSupport::TestCase
  test "belongs to the user and the bookmarked record" do
    bookmark = Bookmark.create!(user: users(:one), bookmarkable: static_pages(:privacy))

    assert_equal [ bookmark ], users(:one).bookmarks
    assert_equal [ bookmark ], static_pages(:privacy).bookmarks
    assert_equal static_pages(:privacy), bookmark.bookmarkable
  end

  test "lets the same user bookmark a record only once" do
    Bookmark.create!(user: users(:one), bookmarkable: static_pages(:privacy))
    duplicate = Bookmark.new(user: users(:one), bookmarkable: static_pages(:privacy))

    assert_not duplicate.valid?
  end

  test "allows another user to bookmark the same page" do
    Bookmark.create!(user: users(:one), bookmarkable: static_pages(:privacy))

    assert Bookmark.create!(user: users(:two), bookmarkable: static_pages(:privacy))
  end
end
