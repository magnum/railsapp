require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "creates a personal account when none is assigned" do
    user = User.create!(
      firstname: "Ada",
      lastname: "Lovelace",
      email: "ada@example.com",
      password: "password1",
      password_confirmation: "password1"
    )

    assert_predicate user.account_id, :present?
    assert_equal user, user.account.user
  end

  test "does not create another account when one is already assigned" do
    existing = accounts(:one)

    user = User.create!(
      account: existing,
      firstname: "Bob",
      lastname: "Ross",
      email: "bob@example.com",
      password: "password1",
      password_confirmation: "password1"
    )

    assert_equal existing.id, user.account_id
    assert_not_equal user, existing.reload.user
  end
end
