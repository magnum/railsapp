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

  test "shows the google connect command when allowed and configured" do
    with_google_connect(allowed: true, configured: true) do
      get sign_in_path
      assert_select "a[href='/auth/google_oauth2']", text: "Connect with Google"

      get sign_up_path
      assert_select "a[href='/auth/google_oauth2']", text: "Connect with Google"
    end
  end

  test "hides the google connect command when the setting is off" do
    with_google_connect(allowed: false, configured: true) do
      get sign_in_path
      assert_select "a[href='/auth/google_oauth2']", count: 0

      get sign_up_path
      assert_select "a[href='/auth/google_oauth2']", count: 0
    end
  end

  test "hides the google connect command when google is not configured" do
    with_google_connect(allowed: true, configured: false) do
      get sign_in_path
      assert_select "a[href='/auth/google_oauth2']", count: 0
    end
  end

  test "google sign in is refused when the setting is off" do
    user = users(:one)
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-blocked",
      info: { email: user.email, first_name: "Other", last_name: "Name", name: "Other Name" }
    )

    with_google_connect(allowed: false, configured: true) do
      assert_no_difference "User.count" do
        get "/auth/google_oauth2/callback", env: { "omniauth.auth" => auth }
      end
    end

    assert_redirected_to sign_in_path
    assert_equal "Authentication with Google failed.", flash[:alert]
    assert_nil user.reload.provider
  end

  test "sign in page shows the magic link button when allowed" do
    with_email_magic_link(true) do
      get sign_in_path
      assert_select "form[action='#{sign_in_path}'] input[type='email']", count: 1
      assert_select "form[action='#{sign_in_path}'] input[name='magic_link'][value='Email me a sign-in link']"
    end
  end

  test "sign in page hides the magic link button when disabled" do
    with_email_magic_link(false) do
      get sign_in_path
      assert_select "input[name='magic_link']", count: 0
    end
  end

  test "magic link email signs in the existing user once" do
    user = users(:one)

    with_email_magic_link(true) do
      assert_emails 1 do
        post sign_in_path, params: { email: user.email.upcase, magic_link: "Email me a sign-in link" }
      end

      assert_redirected_to sign_in_magic_link_prompt_path
      assert_equal "If an account exists for that email, we sent a sign-in link and a code.", flash[:notice]
      follow_redirect!
      assert_select "ol li", text: "Open the email and click the sign-in link."
      assert_select "form[action='#{sign_in_magic_code_path}'] input[name='code']"

      token = magic_link_token
      assert token

      get consume_sign_in_magic_link_path(token)
      assert_redirected_to root_path
      assert_equal user.id, session[:user_id]

      get consume_sign_in_magic_link_path(token)
      assert_redirected_to sign_in_path
      assert_equal "That sign-in link is invalid or has expired.", flash[:alert]
    end
  end

  test "magic code from the email signs in once and invalidates the link" do
    user = users(:one)

    with_email_magic_link(true) do
      post sign_in_path, params: { email: user.email, magic_link: "Email me a sign-in link" }
      code = magic_link_code
      token = magic_link_token
      assert code
      assert token

      post sign_in_magic_code_path, params: { code: code.downcase }
      assert_redirected_to root_path
      assert_equal user.id, session[:user_id]

      delete sign_out_path
      get consume_sign_in_magic_link_path(token)
      assert_redirected_to sign_in_path
      assert_nil session[:user_id]
    end
  end

  test "invalid magic code stays on the prompt" do
    with_email_magic_link(true) do
      post sign_in_magic_link_path, params: { email: users(:one).email }
      post sign_in_magic_code_path, params: { code: "ZZZZ-ZZZZ" }
    end

    assert_redirected_to sign_in_magic_link_prompt_path
    assert_equal "That code is invalid or has expired.", flash[:alert]
    assert_nil session[:user_id]
    follow_redirect!
    assert_select "form[action='#{sign_in_magic_code_path}'] input[name='code']"
  end

  test "unknown email does not send a magic link" do
    with_email_magic_link(true) do
      assert_no_emails do
        post sign_in_magic_link_path, params: { email: "missing@example.com" }
      end
    end

    assert_redirected_to sign_in_magic_link_prompt_path
    assert_equal "If an account exists for that email, we sent a sign-in link and a code.", flash[:notice]
  end

  test "magic link request is refused when the setting is off" do
    with_email_magic_link(false) do
      assert_no_emails do
        post sign_in_magic_link_path, params: { email: users(:one).email }
      end
    end

    assert_redirected_to sign_in_path
    assert_equal "Sign-in links are not available.", flash[:alert]
  end

  test "expired magic link does not sign in" do
    user = users(:one)

    with_email_magic_link(true) do
      post sign_in_magic_link_path, params: { email: user.email }
      token = magic_link_token
      user.update_columns(magic_link_sent_at: 16.minutes.ago)

      get consume_sign_in_magic_link_path(token)
    end

    assert_redirected_to sign_in_path
    assert_nil session[:user_id]
  end

  test "a magic link for a two-factor account stops at the code prompt" do
    user = users(:one)
    user.otp_secret = ROTP::Base32.random
    user.otp_enabled_at = Time.current
    user.save!(validate: false)

    with_email_magic_link(true) do
      post sign_in_magic_link_path, params: { email: user.email }
      get consume_sign_in_magic_link_path(magic_link_token)
    end

    assert_redirected_to sign_in_two_factor_path
    assert_nil session[:user_id]
  end

  private

  def magic_link_body
    mail = ActionMailer::Base.deliveries.last
    mail.text_part&.decoded || mail.body.decoded
  end

  def magic_link_token
    magic_link_body[%r{sign_in/magic_link/([a-f0-9]+)}, 1]
  end

  def magic_link_code
    magic_link_body[/\b[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}\b/]
  end

  def with_email_magic_link(allowed)
    previous = Settings.auth.allow_email_magic_link
    Settings.auth.allow_email_magic_link = allowed
    yield
  ensure
    Settings.auth.allow_email_magic_link = previous
  end

  def with_google_connect(allowed:, configured:)
    previous_allowed = Settings.auth.allow_connect_google
    previous_id = ENV["GOOGLE_CLIENT_ID"]
    previous_secret = ENV["GOOGLE_CLIENT_SECRET"]
    Settings.auth.allow_connect_google = allowed
    if configured
      ENV["GOOGLE_CLIENT_ID"] = "client-id"
      ENV["GOOGLE_CLIENT_SECRET"] = "client-secret"
    else
      ENV.delete("GOOGLE_CLIENT_ID")
      ENV.delete("GOOGLE_CLIENT_SECRET")
    end

    invitation = invitations(:one)
    invitation.update!(state: "created", valid_from: 1.day.ago, valid_to: 1.day.from_now, consumed_at: nil)
    cookies[InvitationProtected::INVITATION_COOKIE] = "#{invitation.id},#{invitation.signature}"

    yield
  ensure
    Settings.auth.allow_connect_google = previous_allowed
    restore_env("GOOGLE_CLIENT_ID", previous_id)
    restore_env("GOOGLE_CLIENT_SECRET", previous_secret)
  end

  def restore_env(key, value)
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end
  end
end
