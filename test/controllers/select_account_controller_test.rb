# frozen_string_literal: true

require "test_helper"

class SelectAccountControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(password: "password1", password_confirmation: "password1")
    @account = accounts(:one)
    @other_account = Account.create!(name: "Other")
  end

  test "admin sets selected_account_id in session" do
    @user.add_role(:admin)
    sign_in_as(@user)

    post select_account_path, params: { account_id: @other_account.id }

    assert_equal @other_account.id.to_s, session[:selected_account_id]
    assert_redirected_to admin_root_path
  end

  test "non-admin ignores selected_account_id" do
    sign_in_as(@user)

    post select_account_path, params: { account_id: @other_account.id }

    assert_nil session[:selected_account_id]
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password1" }
  end
end
