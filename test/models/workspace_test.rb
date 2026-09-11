# frozen_string_literal: true

require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "is valid with a principal user" do
    workspace = Workspace.new(user: users(:two))
    assert workspace.valid?
  end

  test "requires a principal user" do
    workspace = Workspace.new
    assert_not workspace.valid?
  end

  test "defaults name to My Workspace when none is given" do
    workspace = Workspace.create!(user: users(:two))
    assert_equal "My Workspace", workspace.name
  end

  test "keeps an explicit name" do
    workspace = Workspace.create!(user: users(:two), name: "Acme")
    assert_equal "Acme", workspace.name
  end

  test "assigns the principal as a member when they have no workspace" do
    user = User.create!(
      firstname: "Ada",
      lastname: "Lovelace",
      email: "ada-workspace@example.com",
      password: "password1",
      password_confirmation: "password1"
    )

    assert_predicate user.workspace, :present?
    assert_equal "My Workspace", user.workspace.name
    assert_equal user, user.workspace.user
    assert_includes user.workspace.users, user
  end
end
