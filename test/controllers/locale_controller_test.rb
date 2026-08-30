# frozen_string_literal: true

require "test_helper"

class LocaleControllerTest < ActionDispatch::IntegrationTest
  test "update stores locale in session and redirects back" do
    get root_path
    assert_equal "en", session[:locale]

    get set_session_locale_path(locale: "it"), headers: { "HTTP_REFERER" => "#{root_url}?locale=en" }
    assert_redirected_to root_path
    follow_redirect!
    assert_equal "it", session[:locale]
  end

  test "update rewrites static page url to match selected locale" do
    get privacy_policy_url = static_page_path(slug: "privacy-policy", locale: "it")
    assert_response :success

    get set_session_locale_path(locale: "en"), headers: { "HTTP_REFERER" => privacy_policy_url }
    assert_redirected_to static_page_path(slug: "privacy-policy")
  end

  test "update ignores invalid locale" do
    get root_path
    get set_session_locale_path(locale: "xx"), headers: { "HTTP_REFERER" => root_url }
    assert_redirected_to root_path
    assert_equal "en", session[:locale]
  end

  test "home header shows italian after locale switch" do
    get root_path
    assert_select "a", text: "Sign in"

    get set_session_locale_path(locale: "it"), headers: { "HTTP_REFERER" => "#{root_url}?locale=en" }
    follow_redirect!

    assert_select "a", text: "Accedi"
    assert_select "option[selected]", text: "IT"
  end
end
