# frozen_string_literal: true

module Users
  class PassKeysController < ApplicationController
    include WebAuthnRelyingParty

    before_action :require_authentication
    before_action :set_user
    before_action :authorize_pass_keys

    def options
      @user.ensure_webauthn_id!
      registration = relying_party.options_for_registration(
        user: { id: @user.webauthn_id, name: @user.email, display_name: @user.full_name },
        exclude: @user.pass_keys.pluck(:external_id),
        authenticator_selection: { user_verification: "preferred", resident_key: "preferred" }
      )
      session[:webauthn_registration_challenge] = registration.challenge
      render json: registration
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

    def authorize_pass_keys
      authorize @user, :manage_pass_keys?
    rescue Pundit::NotAuthorizedError
      redirect_to root_path, alert: t("views.auth.not_authorized")
    end
  end
end