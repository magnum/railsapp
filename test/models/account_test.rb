# frozen_string_literal: true

require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "is valid with a principal user" do
    account = Account.new(user: users(:two))
    assert account.valid?
  end

  test "requires a principal user" do
    account = Account.new
    assert_not account.valid?
  end

  test "assigns the principal as a member when they have no account" do
    user = User.create!(
      firstname: "Ada",
      lastname: "Lovelace",
      email: "ada-account@example.com",
      password: "password1",
      password_confirmation: "password1"
    )

    assert_predicate user.account, :present?
    assert_equal user, user.account.user
    assert_includes user.account.users, user
  end
end
