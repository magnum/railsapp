# frozen_string_literal: true

module RequireTwoFactorSetup
  extend ActiveSupport::Concern

  included do
    before_action :redirect_until_two_factor_setup
  end

  private

  def redirect_until_two_factor_setup
    user = current_user
    return unless user&.two_factor_setup_required?
    return if two_factor_setup_allowed?(user)

    redirect_to user_path(user), alert: t("users.two_factor.setup_required"), status: :see_other
  end

  def two_factor_setup_allowed?(user)
    case controller_path
    when "sessions", "locale"
      true
    when "users"
      params[:id].to_s == user.id.to_s && %w[show edit update].include?(action_name)
    when "users/two_factors", "users/pass_keys"
      params[:user_id].to_s == user.id.to_s
    else
      false
    end
  end
end
