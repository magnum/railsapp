# frozen_string_literal: true

module Users
  class TwoFactorsController < ApplicationController
    before_action :require_authentication
    before_action :set_user
    before_action :authorize_two_factor

    def create
      return redirect_to @user if @user.two_factor_active?

      @user.start_two_factor_setup!
      redirect_to user_path(@user, two_factor: "setup"), status: :see_other
    end

    def confirm
      codes = @user.confirm_two_factor!(params[:otp_code])
      if codes
        session[:two_factor_backup_codes] = { "user_id" => @user.id, "codes" => codes }
        redirect_to user_path(@user, two_factor: "backup"), notice: t("users.two_factor.enabled"), status: :see_other
      else
        redirect_to user_path(@user, two_factor: "setup"), alert: t("users.two_factor.invalid_code"), status: :see_other
      end
    end

    def destroy
      @user.disable_two_factor!
      session.delete(:two_factor_backup_codes)
      redirect_to @user, notice: t("users.two_factor.disabled"), status: :see_other
    end

    def backup_codes
      codes = backup_codes_for_download
      if codes.blank?
        redirect_to @user, alert: t("users.two_factor.backup_codes_unavailable"), status: :see_other
        return
      end

      send_data "#{codes.join("\n")}\n", filename: "backup-codes.txt", type: "text/plain", disposition: "attachment"
    end

    def dismiss_backup_codes
      session.delete(:two_factor_backup_codes)
      redirect_to @user, status: :see_other
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

    def authorize_two_factor
      authorize @user, :manage_two_factor?
    rescue Pundit::NotAuthorizedError
      redirect_to root_path, alert: t("views.auth.not_authorized")
    end

    def backup_codes_for_download
      stored = session[:two_factor_backup_codes]
      return unless stored.is_a?(Hash) && stored["user_id"].to_i == @user.id

      Array(stored["codes"]).presence
    end
  end
end
