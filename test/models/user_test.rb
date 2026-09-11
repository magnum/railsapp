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
end
