# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "google sign in links the existing user with the same email" do
    user = users(:one)
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-existing",
      info: {
        email: user.email.upcase,
        first_name: "Other",
        last_name: "Name",
        name: "Other Name",
        image: "https://example.com/avatar.png"
      }
    )

    assert_no_difference "User.count" do
      get "/auth/google_oauth2/callback", env: { "omniauth.auth" => auth }
    end

    assert_redirected_to root_path
    assert_equal "Signed in successfully.", flash[:notice]
    assert_equal user.id, session[:user_id]
    assert_equal "google_oauth2", user.reload.provider
    assert_equal "google-uid-existing", user.uid
    assert_equal "MyString", user.firstname
  end
end
