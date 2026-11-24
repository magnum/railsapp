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

    test "removing the code requires a fresh factor and then stops asking for it" do
      sign_in_as(@user)
      enable_two_factor(@user)
      delete backup_codes_user_two_factor_path(@user)

      get user_path(@user)
      assert_select "form[action='#{user_two_factor_path(@user)}'] input[name='otp_code']"

      delete user_two_factor_path(@user)
      assert_redirected_to user_path(@user)
      assert @user.reload.two_factor_active?

      backup = "ABCD2345"
      @user.backup_codes.create!(code_digest: Digest::SHA256.hexdigest(backup))
      delete user_two_factor_path(@user), params: { otp_code: backup.downcase }
      assert_redirected_to user_path(@user)
      assert_not @user.reload.two_factor_active?
      assert_equal 0, @user.backup_codes.count

      sign_in_as(@user)
      enable_two_factor(@user)
      travel 30.seconds do
        delete user_two_factor_path(@user), params: { otp_code: ROTP::TOTP.new(@user.reload.otp_secret).now }
      end
      assert_redirected_to user_path(@user)
      assert_not @user.reload.two_factor_active?

      delete sign_out_path
      post sign_in_path, params: { email: @user.email, password: "password1" }
      assert_redirected_to root_path
      assert_equal @user.id, session[:user_id]
    end

    test "repeated second-factor failures lock the account outside the session" do
      sign_in_as(@user)
      enable_two_factor(@user)
      delete sign_out_path
      post sign_in_path, params: { email: @user.email, password: "password1" }
      assert_redirected_to sign_in_two_factor_path

      TwoFactorAuthenticatable::OTP_MAX_ATTEMPTS.times do |index|
        post sign_in_two_factor_path, params: { otp_code: "000000" }
        if index + 1 == TwoFactorAuthenticatable::OTP_MAX_ATTEMPTS
          assert_redirected_to sign_in_path
        else
          assert_response :unprocessable_entity
        end
      end
      assert_nil session[:pending_2fa_user_id]
      assert @user.reload.otp_locked_until.future?

      post sign_in_path, params: { email: @user.email, password: "password1" }
      assert_redirected_to sign_in_path
      assert_nil session[:user_id]
      assert_nil session[:pending_2fa_user_id]

      travel TwoFactorAuthenticatable::OTP_LOCKOUT + 1.second do
        post sign_in_path, params: { email: @user.email, password: "password1" }
        assert_redirected_to sign_in_two_factor_path
        assert_equal 0, @user.reload.otp_failed_attempts
      end
    end

    test "an unreadable authenticator secret still requires the second factor" do
      sign_in_as(@user)
      enable_two_factor(@user)
      backup = @user.backup_codes.first
      known = "WXYZ2345"
      backup.update!(code_digest: Digest::SHA256.hexdigest(known))
      @user.update_columns(otp_secret_ciphertext: "not-a-valid-secret")
      assert @user.reload.two_factor_active?
      assert_nil @user.otp_secret

      delete sign_out_path
      post sign_in_path, params: { email: @user.email, password: "password1" }
      assert_redirected_to sign_in_two_factor_path

      post sign_in_two_factor_path, params: { otp_code: "000000" }
      assert_response :unprocessable_entity
      assert_nil session[:user_id]

      post sign_in_two_factor_path, params: { otp_code: known }
      assert_redirected_to root_path
      assert_equal @user.id, session[:user_id]
    end

    test "another user cannot set up two-factor authentication" do
      sign_in_as(@other)

      post user_two_factor_path(@user)
      assert_redirected_to root_path
      assert_nil @user.reload.otp_pending_secret
    end

    test "an enabled second factor is still requested when setup is not required" do
      sign_in_as(@user)
      enable_two_factor(@user)
      delete sign_out_path

      with_two_factor_flags(required: false, required_for_admin: false) do
        post sign_in_path, params: { email: @user.email, password: "password1" }
      end

      assert_redirected_to sign_in_two_factor_path
      assert_nil session[:user_id]
    end

    test "a user without two-factor is kept on their profile when it is required" do
      with_two_factor_flags(required: true, required_for_admin: false) do
        sign_in_as(@user)
        assert_redirected_to user_path(@user)
        follow_redirect!
        assert_match "Add a second factor on this page", response.body

        get root_path
        assert_redirected_to user_path(@user)

        get edit_user_path(@user)
        assert_response :success

        get user_path(@other)
        assert_redirected_to user_path(@user)

        get admin_root_path
        assert_redirected_to user_path(@user)

        delete sign_out_path
        assert_redirected_to sign_in_path
      end
    end

    test "only admins must set up two-factor when that setting is on" do
      @user.add_role(:admin)

      with_two_factor_flags(required: false, required_for_admin: true) do
        sign_in_as(@user)
        assert_redirected_to user_path(@user)

        delete sign_out_path
        sign_in_as(@other)
        assert_redirected_to root_path

        get root_path
        assert_response :success
      end
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

    def with_two_factor_flags(required:, required_for_admin:)
      previous_required = Settings.auth["2fa_required"]
      previous_admin = Settings.auth["2fa_required_for_admin"]
      Settings.auth["2fa_required"] = required
      Settings.auth["2fa_required_for_admin"] = required_for_admin
      yield
    ensure
      Settings.auth["2fa_required"] = previous_required
      Settings.auth["2fa_required_for_admin"] = previous_admin
    end
  end
end
