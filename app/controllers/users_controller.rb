# frozen_string_literal: true

class UsersController < ApplicationController
  include WebAuthnRelyingParty

  before_action :require_authentication
  before_action :require_admin_for_index, only: [:index]
  before_action :set_user, only: [:show, :edit, :update]

  def index
    @users = policy_scope(current_workspace.users).order(:lastname, :firstname)
  end

  def show
    authorize @user
    @backup_codes = backup_codes_for_current_user
  end

  def edit
    authorize @user
  end

  def update
    authorize @user
    @user.assign_attributes(user_params)
    prepare_new_pass_keys
    if @user.save
      session.delete(:webauthn_registration_challenge)
      redirect_to @user, notice: t("users.updated"), status: :see_other
    else
      @backup_codes = backup_codes_for_current_user
      render (pass_keys_update? ? :show : :edit), status: :unprocessable_entity
    end
  end

  private

  def require_admin_for_index
    return if current_user.admin?
    redirect_to root_path, alert: t("views.auth.not_authorized")
  end

  def set_user
    @user = User.find(params[:id])
  end

  def backup_codes_for_current_user
    stored = session[:two_factor_backup_codes]
    return unless stored.is_a?(Hash) && stored["user_id"].to_i == @user.id && @user == current_user

    Array(stored["codes"]).presence
  end

  def user_params
    permitted = [ :firstname, :lastname, :email ]
    permitted << { pass_keys_attributes: [ :id, :name, :credential, :_destroy ] } if current_user == @user
    params.require(:user).permit(*permitted)
  end

  def pass_keys_update?
    params.dig(:user, :pass_keys_attributes).present?
  end

  def prepare_new_pass_keys
    @user.pass_keys.each do |pass_key|
      next if pass_key.persisted?

      pass_key.webauthn_challenge = session[:webauthn_registration_challenge]
      pass_key.relying_party = relying_party
    end
  end
end
