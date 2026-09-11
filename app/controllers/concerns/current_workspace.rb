# frozen_string_literal: true

module CurrentWorkspace
  extend ActiveSupport::Concern

  included do
    before_action :set_current_workspace
    helper_method :current_workspace
  end

  private

  def current_workspace
    @current_workspace
  end

  def set_current_workspace
    return unless current_user

    if current_user.admin? && session[:selected_workspace_id].present?
      @current_workspace = Workspace.find_by(id: session[:selected_workspace_id])
    end

    @current_workspace ||= current_user.workspace
    Current.workspace = @current_workspace
  end
end
