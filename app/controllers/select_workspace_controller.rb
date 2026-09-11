# frozen_string_literal: true

class SelectWorkspaceController < ApplicationController
  before_action :require_login

  def create
    if current_user.admin? && params[:workspace_id].present?
      session[:selected_workspace_id] = params[:workspace_id]
    end

    redirect_back fallback_location: admin_root_path
  end
end
