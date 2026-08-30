# frozen_string_literal: true

require "test_helper"

class StaticPageTest < ActiveSupport::TestCase
  setup do
    @dir = Pathname(Dir.mktmpdir)
    File.write(@dir.join("sample.en.html.erb"), "english")
    @page = StaticPage.new(views_path: @dir)
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "uses requested locale when that template exists" do
    File.write(@dir.join("sample.it.html.erb"), "italian")

    assert_equal "it", @page.resolve_locale("sample", "it")
    assert_equal "en", @page.resolve_locale("sample", "en")
  end

  test "falls back to default locale when requested template is missing" do
    assert_equal "en", @page.resolve_locale("sample", "it")
  end

  test "unprefixed request uses default locale" do
    assert_equal "en", @page.resolve_locale("sample", nil)
  end

  test "unknown slug returns nil" do
    assert_nil @page.resolve_locale("missing", "en")
    assert_nil @page.resolve_locale("missing", nil)
  end

  test "rejects unsafe slugs" do
    assert_nil @page.resolve_locale("../secret", "en")
    assert_nil @page.resolve_locale("sample.html", "en")
  end
end
