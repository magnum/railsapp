# frozen_string_literal: true

require "test_helper"

class SelectWorkspaceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(password: "password1", password_confirmation: "password1")
    @workspace = workspaces(:one)
    @other_workspace = Workspace.create!(user: users(:two))
  end

  test "admin sets selected_workspace_id in session" do
    @user.add_role(:admin)
    sign_in_as(@user)

    post select_workspace_path, params: { workspace_id: @other_workspace.id }

    assert_equal @other_workspace.id.to_s, session[:selected_workspace_id]
    assert_redirected_to admin_root_path
  end

  test "non-admin ignores selected_workspace_id" do
    sign_in_as(@user)

    post select_workspace_path, params: { workspace_id: @other_workspace.id }

    assert_nil session[:selected_workspace_id]
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password1" }
  end
end
