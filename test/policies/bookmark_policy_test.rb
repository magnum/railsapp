# frozen_string_literal: true

require "test_helper"

class BookmarkPolicyTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @other = users(:two)
    @bookmark = Bookmark.create!(user: @owner, bookmarkable: static_pages(:privacy))
  end

  test "a user manages only their own bookmarks" do
    policy = BookmarkPolicy.new(@owner, @bookmark)
    foreign = BookmarkPolicy.new(@other, @bookmark)
    own_new = BookmarkPolicy.new(@other, Bookmark.new(user: @other, bookmarkable: static_pages(:privacy)))

    assert policy.show?
    assert policy.update?
    assert policy.destroy?
    assert own_new.create?
    assert_not foreign.show?
    assert_not foreign.create?
    assert_not foreign.update?
    assert_not foreign.destroy?
    assert_equal [ @bookmark ], BookmarkPolicy::Scope.new(@owner, Bookmark.all).resolve
    assert_empty BookmarkPolicy::Scope.new(@other, Bookmark.all).resolve
  end

  test "an admin manages bookmarks that belong to someone else" do
    @other.add_role(:admin)
    policy = BookmarkPolicy.new(@other, @bookmark)
    created = BookmarkPolicy.new(@other, Bookmark.new(user: @owner, bookmarkable: static_pages(:privacy)))

    assert policy.show?
    assert policy.update?
    assert policy.destroy?
    assert created.create?
    assert_equal Bookmark.count, BookmarkPolicy::Scope.new(@other, Bookmark.all).resolve.count
  end
end
