# frozen_string_literal: true

class UsersController < ApplicationController
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
    if @user.update(user_params)
      redirect_to @user, notice: t("users.updated")
    else
      render :edit, status: :unprocessable_entity
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
    params.require(:user).permit(:firstname, :lastname, :email)
  end
end
