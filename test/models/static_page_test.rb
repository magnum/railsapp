# frozen_string_literal: true

require "test_helper"

class StaticPageTest < ActiveSupport::TestCase
  setup do
    @page = static_pages(:privacy)
  end

  test "validates slug format" do
    page = StaticPage.new(slug: "../secret", title: "Bad")
    assert_not page.valid?
  end

  test "resolve_template prefers requested locale" do
    assert_equal "privacy-policy.it", StaticPage.resolve_template("privacy-policy", "it")
  end

  test "resolve_template falls back to default locale file" do
    assert_equal "privacy-policy.en", StaticPage.resolve_template("privacy-policy", "xx")
  end

  test "resolve_template returns nil for unknown slug" do
    assert_nil StaticPage.resolve_template("missing-page")
  end

  test "is_editor includes admin and editor roles" do
    admin = users(:one)
    admin.add_role(:admin)
    assert admin.is_editor?
  end
end
