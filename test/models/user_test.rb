require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "creates a personal workspace when none is assigned" do
    user = User.create!(
      firstname: "Ada",
      lastname: "Lovelace",
      email: "ada@example.com",
      password: "password1",
      password_confirmation: "password1"
    )

    assert_predicate user.workspace_id, :present?
    assert_equal user, user.workspace.user
  end

  test "does not create another workspace when one is already assigned" do
    existing = workspaces(:one)

    user = User.create!(
      workspace: existing,
      firstname: "Bob",
      lastname: "Ross",
      email: "bob@example.com",
      password: "password1",
      password_confirmation: "password1"
    )

    assert_equal existing.id, user.workspace_id
    assert_not_equal user, existing.reload.user
  end

  test "links a google account to the user with the same email" do
    user = users(:one)
    auth = google_auth(email: user.email.upcase, uid: "google-uid-1", first_name: "Other", last_name: "Name")

    assert_no_difference "User.count" do
      linked = User.from_omniauth(auth, workspace: workspaces(:one))
      assert_equal user, linked
    end

    user.reload
    assert_equal "google_oauth2", user.provider
    assert_equal "google-uid-1", user.uid
    assert_equal "https://example.com/avatar.png", user.avatar_url
    assert_equal "MyString", user.firstname
    assert_equal "MyString", user.lastname
    assert_equal "user_one@example.com", user.email
  end

  test "signs in an already linked google account without creating a user" do
    user = users(:one)
    user.update!(provider: "google_oauth2", uid: "google-uid-1")
    auth = google_auth(email: user.email, uid: "google-uid-1", first_name: "Updated", last_name: "Person")

    assert_no_difference "User.count" do
      assert_equal user, User.from_omniauth(auth)
    end

    assert_equal "Updated", user.reload.firstname
    assert user.identities.exists?(provider: "google_oauth2", uid: "google-uid-1")
  end

  test "an existing google login still matches from the stored provider" do
    user = users(:one)
    user.update!(provider: "google_oauth2", uid: "legacy-google-uid")
    user.identities.delete_all
    auth = google_auth(email: user.email, uid: "legacy-google-uid", first_name: "Ada", last_name: "Lovelace")

    assert_no_difference "User.count" do
      assert_equal user, User.from_omniauth(auth)
    end

    user.reload
    assert_equal "google_oauth2", user.provider
    assert_equal "legacy-google-uid", user.uid
    assert user.identities.exists?(provider: "google_oauth2", uid: "legacy-google-uid")
  end

  test "password sign in still works after linking google" do
    user = User.create!(
      firstname: "Ada",
      lastname: "Lovelace",
      email: "ada-password@example.com",
      password: "password1",
      password_confirmation: "password1"
    )
    auth = google_auth(email: user.email, uid: "google-uid-password", first_name: "Ada", last_name: "Lovelace")

    assert_equal user, User.from_omniauth(auth)

    assert user.reload.authenticate("password1")
    assert_equal "google_oauth2", user.provider
  end

  test "links a microsoft account when only preferred_username is an email" do
    user = users(:one)
    auth = OmniAuth::AuthHash.new(
      provider: "entra_id",
      uid: "microsoft-uid-1",
      info: { email: nil, name: "Other Name" },
      extra: { raw_info: { "preferred_username" => user.email.upcase } }
    )

    assert_no_difference "User.count" do
      assert_equal user, User.from_omniauth(auth)
    end

    user.reload
    assert_equal "entra_id", user.provider
    assert_equal "microsoft-uid-1", user.uid
    assert_equal "user_one@example.com", user.email
  end

  test "keeps google and microsoft on the same user" do
    user = users(:one)
    google = google_auth(email: user.email, uid: "google-uid-1", first_name: "Ada", last_name: "Lovelace")
    microsoft = OmniAuth::AuthHash.new(
      provider: "entra_id",
      uid: "microsoft-uid-1",
      info: { email: user.email, name: "Ada Lovelace" }
    )

    assert_no_difference "User.count" do
      assert_equal user, User.from_omniauth(google)
      assert_equal user, User.from_omniauth(microsoft)
      assert_equal user, User.from_omniauth(google)
    end

    assert_equal [ "entra_id", "google_oauth2" ], user.identities.order(:provider).pluck(:provider)
    assert_equal "google_oauth2", user.reload.provider
    assert_equal "google-uid-1", user.uid
  end

  test "a different email stays a different user" do
    user = users(:one)
    User.from_omniauth(google_auth(email: user.email, uid: "google-uid-1", first_name: "Ada", last_name: "Lovelace"))

    other = nil
    assert_difference "User.count", 1 do
      other = User.from_omniauth(google_auth(email: "other-ada@example.com", uid: "google-uid-2", first_name: "Other", last_name: "Ada"))
    end

    assert_not_equal user.id, other.id
    assert_equal [ "google_oauth2" ], user.identities.pluck(:provider)
    assert_equal [ "google_oauth2" ], other.identities.pluck(:provider)
  end

  private

  def google_auth(email:, uid:, first_name:, last_name:)
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: {
        email: email,
        first_name: first_name,
        last_name: last_name,
        name: "#{first_name} #{last_name}",
        image: "https://example.com/avatar.png"
      }
    )
  end
end
