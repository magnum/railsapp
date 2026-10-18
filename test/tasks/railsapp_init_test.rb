# frozen_string_literal: true

require "test_helper"
require "rake"

class RailsappInitTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("railsapp:init")
    Rake::Task["railsapp:init"].reenable
  end

  test "creates the first workspace and admin user" do
    clear_bootstrap_records
    stdin = StringIO.new("Ada@Example.com\nAda\nLovelace\npassword1\n")

    with_stdin(stdin) { Rake::Task["railsapp:init"].invoke }

    workspace = Workspace.order(:id).first
    user = User.find_by(email: "ada@example.com")

    assert_equal 1, Workspace.count
    assert_equal "My Workspace", workspace.name
    assert_equal user, workspace.user
    assert_equal workspace, user.workspace
    assert_equal "Ada", user.firstname
    assert_equal "Lovelace", user.lastname
    assert user.authenticate("password1")
    assert user.admin?
  end

  test "does nothing when a workspace and an admin already exist" do
    users(:one).add_role(:admin)

    assert_no_difference ["Workspace.count", "User.count"] do
      with_stdin(StringIO.new("")) { Rake::Task["railsapp:init"].invoke }
    end
  end

  private

  def with_stdin(io)
    previous = $stdin
    $stdin = io
    yield
  ensure
    $stdin = previous
  end

  def clear_bootstrap_records
    Plan.delete_all
    ApiKey.delete_all
    Invitation.delete_all
    StaticPage.delete_all
    Webhook.delete_all
    Bookmark.delete_all
    ActiveRecord::Base.connection.execute("DELETE FROM users_roles")
    User.update_all(workspace_id: nil)
    Workspace.update_all(user_id: nil)
    User.delete_all
    Workspace.delete_all
  end
end
