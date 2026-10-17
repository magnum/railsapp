# frozen_string_literal: true

require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "privacy policy without locale uses default english view" do
    get "/privacy-policy"

    assert_response :success
    assert_select "article.static-page .lexxy-content"
    assert_match "Privacy policy", response.body
    assert_match "Antonio Molinari", response.body
    assert_google_user_data_disclosures
  end

  test "privacy policy italian url" do
    get "/it/privacy-policy"

    assert_response :success
    assert_match "Informativa sulla privacy", response.body
  end

  test "terms and conditions english and italian" do
    get "/terms-and-conditions"
    assert_response :success
    assert_match "Terms and conditions", response.body

    get "/it/terms-and-conditions"
    assert_response :success
    assert_match "Termini e condizioni", response.body
  end

  test "cookie policy english and italian" do
    get "/cookie-policy"
    assert_response :success
    assert_match "Cookie policy", response.body

    get "/it/cookie-policy"
    assert_response :success
    assert_match "Informativa cookie", response.body
  end

  test "legal pages include footer links" do
    get "/privacy-policy"

    assert_select "footer"
    assert_select "footer a[href=?]", "/privacy-policy"
    assert_select "footer a[href=?]", "/terms-and-conditions"
    assert_select "footer a[href=?]", "/cookie-policy"
  end

  test "404 page renders custom content" do
    get app_not_found_path

    assert_response :success
    assert_includes response.body, "content not found"
  end

  test "unknown static page redirects to 404 page" do
    get "/does-not-exist"

    assert_redirected_to app_not_found_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "content not found"
  end

  test "existing app routes are not captured by static pages" do
    get sign_in_path

    assert_response :success
    assert_select "form"
  end

  test "editor lists static pages with bookmark stars" do
    user = users(:one)
    user.update!(password: "password1", password_confirmation: "password1")
    user.add_role(:admin)
    sign_in_as(user)

    get static_pages_path

    assert_response :success
    assert_select "h2", text: I18n.t("bookmarks.title"), count: 0
    assert_select ".static-pages-list span.bookmark-link.is-disabled", count: 1
    assert_select ".static-page-row button.bookmark-link[data-bookmark-link-type-value=StaticPage][data-bookmark-link-id-value=?]:not(.is-starred)", static_pages(:privacy).id.to_s
  end

  test "bookmarked static pages are listed before the results" do
    user = users(:one)
    user.update!(password: "password1", password_confirmation: "password1")
    user.add_role(:admin)
    sign_in_as(user)
    privacy = static_pages(:privacy)
    terms = static_pages(:terms)
    cookie = static_pages(:cookie)
    Bookmark.create!(user: users(:two), bookmarkable: privacy)
    Bookmark.create!(user: user, bookmarkable: cookie)
    Bookmark.create!(user: user, bookmarkable: terms)

    get static_pages_path

    assert_response :success
    assert_select "section.static-page-bookmarks h2", text: I18n.t("bookmarks.title")
    rows = css_select("section.static-page-bookmarks .static-page-row")
    assert_equal [ terms.title, cookie.title ], rows.map { |row| row.at("a").text }
    assert_select "section.static-page-bookmarks a", text: privacy.title, count: 0
    assert_select "section.static-page-bookmarks button.bookmark-link.is-starred", count: 2
    assert_select ".static-pages-list", count: 2
    privacy_star = css_select(".static-pages-list").last.at_css("button.bookmark-link[data-bookmark-link-id-value='#{privacy.id}']")
    assert privacy_star
    assert_not_includes privacy_star["class"], "is-starred"
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password1" }
  end

  def assert_google_user_data_disclosures
    assert_select "h2#google-user-data"
    assert_select "h3#google-data-access"
    assert_select "h3#google-data-use"
    assert_select "h3#google-data-sharing"
    assert_select "h3#google-data-protection"
    assert_select "h3#google-data-retention"
  end
end
