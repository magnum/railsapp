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
