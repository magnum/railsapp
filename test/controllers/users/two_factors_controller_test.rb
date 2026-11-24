# frozen_string_literal: true

require "test_helper"

module Users
  class TwoFactorsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @user.update!(password: "password1", password_confirmation: "password1")
      @other = users(:two)
      @other.update!(password: "password1", password_confirmation: "password1")
    end

    test "the owner creates a code, confirms it, and can copy or download backup codes" do
      sign_in_as(@user)

      post user_two_factor_path(@user)
      assert_redirected_to user_path(@user, two_factor: "setup")
      follow_redirect!

      assert_select "dialog.two-factor-dialog svg"
      assert_select "form[action='#{confirm_user_two_factor_path(@user)}'] input[name='otp_code']"
      assert_match(/[A-Z2-7]{4}/, response.body)

      @user.reload
      post confirm_user_two_factor_path(@user), params: { otp_code: "000000" }
      assert_redirected_to user_path(@user, two_factor: "setup")
      assert_nil @user.reload.otp_enabled_at

      post confirm_user_two_factor_path(@user), params: { otp_code: ROTP::TOTP.new(@user.otp_pending_secret).now }
      assert_redirected_to user_path(@user, two_factor: "backup")
      follow_redirect!

      codes = response.body.scan(/\b[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}\b/).uniq
      assert_equal User::BACKUP_CODE_COUNT, codes.size
      assert_equal User::BACKUP_CODE_COUNT, @user.backup_codes.count
      assert_select "button", text: "Copy codes"
      assert_select "a[href='#{backup_codes_user_two_factor_path(@user, format: :txt)}']", text: "Download backup-codes.txt"

      get backup_codes_user_two_factor_path(@user, format: :txt)
      assert_equal "text/plain", response.media_type
      codes.each { |code| assert_includes response.body, code }

      delete sign_out_path
      post sign_in_path, params: { email: @user.email, password: "password1" }
      assert_redirected_to sign_in_two_factor_path
      assert_nil session[:user_id]

      post sign_in_two_factor_path, params: { otp_code: codes.first.downcase }
      assert_redirected_to root_path
      assert_equal @user.id, session[:user_id]
      assert_equal User::BACKUP_CODE_COUNT - 1, @user.backup_codes.count

      delete sign_out_path
      post sign_in_path, params: { email: @user.email, password: "password1" }
      post sign_in_two_factor_path, params: { otp_code: codes.first }
      assert_response :unprocessable_entity
      assert_nil session[:user_id]

      travel 30.seconds do
        post sign_in_two_factor_path, params: { otp_code: ROTP::TOTP.new(@user.reload.otp_secret).now }
      end
      assert_redirected_to root_path
      assert_equal @user.id, session[:user_id]
    end

    test "removing the code stops asking for a second factor" do
      sign_in_as(@user)
      enable_two_factor(@user)

      delete user_two_factor_path(@user)
      assert_redirected_to user_path(@user)
      assert_not @user.reload.two_factor_active?
      assert_equal 0, @user.backup_codes.count

      delete sign_out_path
      post sign_in_path, params: { email: @user.email, password: "password1" }
      assert_redirected_to root_path
      assert_equal @user.id, session[:user_id]
    end

    test "another user cannot set up two-factor authentication" do
      sign_in_as(@other)

      post user_two_factor_path(@user)
      assert_redirected_to root_path
      assert_nil @user.reload.otp_pending_secret
    end

    test "the second factor is skipped when the setting is off" do
      sign_in_as(@user)
      enable_two_factor(@user)
      delete sign_out_path

      with_two_factor(false) do
        post sign_in_path, params: { email: @user.email, password: "password1" }
      end

      assert_redirected_to root_path
      assert_equal @user.id, session[:user_id]
    end

    private

    def sign_in_as(user)
      post sign_in_path, params: { email: user.email, password: "password1" }
    end

    def enable_two_factor(user)
      post user_two_factor_path(user)
      user.reload
      post confirm_user_two_factor_path(user), params: { otp_code: ROTP::TOTP.new(user.otp_pending_secret).now }
      assert_redirected_to user_path(user, two_factor: "backup")
    end

    def with_two_factor(enabled)
      previous = Settings.auth["2fa_required"]
      Settings.auth["2fa_required"] = enabled
      yield
    ensure
      Settings.auth["2fa_required"] = previous
    end
  end
end
