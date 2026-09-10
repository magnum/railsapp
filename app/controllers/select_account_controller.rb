# frozen_string_literal: true

class SelectAccountController < ApplicationController
  before_action :require_login

  def create
    if current_user.admin? && params[:account_id].present?
      session[:selected_account_id] = params[:account_id]
    end

    redirect_back fallback_location: admin_root_path
  end
end
