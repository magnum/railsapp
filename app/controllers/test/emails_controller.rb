# frozen_string_literal: true

module Test
  class EmailsController < ApplicationController
    before_action :require_admin

    def show
    end

    def create
      email_to = params[:email_to].to_s.strip
      text = params[:text].to_s

      unless valid_email?(email_to) && text.present?
        redirect_to test_email_path, alert: t("test_email.invalid")
        return
      end

      TestMailer.test_message(email_to, text).deliver_now
      redirect_to test_email_path, notice: t("test_email.sent", email: email_to)
    rescue StandardError => error
      redirect_to test_email_path, alert: t("test_email.failed", message: error.message)
    end

    private

    def require_admin
      if current_user.blank?
        redirect_to sign_in_path, alert: t("authentication.require_sign_in")
        return
      end

      return if current_user.admin?

      redirect_to root_path, alert: t("views.auth.not_authorized")
    end

    def valid_email?(email)
      email.match?(URI::MailTo::EMAIL_REGEXP)
    end
  end
end
