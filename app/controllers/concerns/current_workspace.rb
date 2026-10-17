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
      selected = Workspace.find_by(id: session[:selected_workspace_id])
      @current_workspace = selected if selectable_workspace?(selected)
    end

    @current_workspace ||= bookmarked_workspace
    @current_workspace ||= current_user.workspace
    Current.workspace = @current_workspace
  end

  def selectable_workspace?(workspace)
    return false if workspace.blank?
    return true if current_user.admin?

    workspace.id == current_user.workspace_id
  end

  def bookmarked_workspace
    bookmark_id = current_user.bookmarks.where(bookmarkable_type: "Workspace").order(created_at: :desc).pick(:bookmarkable_id)
    return if bookmark_id.blank?

    workspace = Workspace.find_by(id: bookmark_id)
    workspace if selectable_workspace?(workspace)
  end
end
