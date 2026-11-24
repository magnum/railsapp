# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class PassKeysTest < ActionDispatch::IntegrationTest
  ORIGIN = "http://www.example.com"

  setup do
    @user = users(:one)
    @user.update!(password: "password1", password_confirmation: "password1")
    @other = users(:two)
    @other.update!(password: "password1", password_confirmation: "password1")
    @authenticator = WebAuthn::FakeAuthenticator.new
    @client = WebAuthn::FakeClient.new(ORIGIN, authenticator: @authenticator)
  end

  test "the profile nested form registers, renames, and removes a passkey" do
    sign_in_as(@user)
    get user_path(@user)
    assert_select "form[action='#{user_path(@user)}'] input[name='new-passkey-name'], input#new-passkey-name"
    assert_select "button", text: "Add passkey"

    post options_user_pass_keys_path(@user), as: :json
    assert_response :success
    challenge = JSON.parse(response.body).fetch("challenge")
    credential = @client.create(challenge: challenge)

    patch user_path(@user), params: {
      user: { pass_keys_attributes: { "0" => { name: "Laptop", credential: credential.to_json } } }
    }
    assert_redirected_to user_path(@user)
    pass_key = @user.pass_keys.sole
    assert_equal "Laptop", pass_key.name

    patch user_path(@user), params: {
      user: { pass_keys_attributes: { "0" => { id: pass_key.id, name: "Phone" } } }
    }
    assert_equal "Phone", pass_key.reload.name

    patch user_path(@user), params: {
      user: { pass_keys_attributes: { "0" => { id: pass_key.id, name: "Phone", _destroy: "1" } } }
    }
    assert_equal 0, @user.pass_keys.count
  end

  test "a passkey signs the user in" do
    sign_in_as(@user)
    register_passkey("Laptop")
    delete sign_out_path

    post sign_in_passkey_options_path, as: :json
    challenge = JSON.parse(response.body).fetch("challenge")
    assertion = @client.get(challenge: challenge)

    post sign_in_passkey_path, params: { credential: assertion.to_json }
    assert_redirected_to root_path
    assert_equal @user.id, session[:user_id]
    assert @user.pass_keys.sole.reload.last_used_at
  end

  test "an invalid passkey does not sign in" do
    post sign_in_passkey_options_path, as: :json
    post sign_in_passkey_path, params: { credential: "{}" }

    assert_redirected_to sign_in_path
    assert_nil session[:user_id]
  end

  test "another user cannot register a passkey on this profile" do
    sign_in_as(@other)

    post options_user_pass_keys_path(@user), as: :json
    assert_redirected_to root_path

    assert_raises(Pundit::NotAuthorizedError) do
      patch user_path(@user), params: {
        user: { pass_keys_attributes: { "0" => { name: "Stolen", credential: "{}" } } }
      }
    end
    assert_equal 0, @user.pass_keys.count
  end

  test "the sign in page offers passkeys" do
    get sign_in_path
    assert_select "button", text: "Sign in with a passkey"
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password1" }
  end

  def register_passkey(name)
    post options_user_pass_keys_path(@user), as: :json
    challenge = JSON.parse(response.body).fetch("challenge")
    credential = @client.create(challenge: challenge)
    patch user_path(@user), params: {
      user: { pass_keys_attributes: { "0" => { name: name, credential: credential.to_json } } }
    }
    assert_redirected_to user_path(@user)
  end
end
