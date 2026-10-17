# frozen_string_literal: true

class BookmarksController < ApplicationController
  before_action :require_login

  def toggle
    bookmarkable = find_bookmarkable
    authorize Bookmark.new(user: current_user, bookmarkable: bookmarkable), :create?
    bookmark = current_user.bookmarks.find_by(bookmarkable: bookmarkable)

    if bookmark
      authorize bookmark, :destroy?
      bookmark.destroy!
      starred = false
    else
      keep_single_bookmark(bookmarkable)
      current_user.bookmarks.create!(bookmarkable: bookmarkable)
      starred = true
    end

    render json: { starred: starred }
  end

  private

  def find_bookmarkable
    raise ActiveRecord::RecordNotFound if params[:bookmarkable_type].blank?

    scope_for(params[:bookmarkable_type]).find(params[:bookmarkable_id])
  end

  def scope_for(type)
    case type
    when "StaticPage"
      policy_scope(current_workspace.static_pages)
    when "MenuItem"
      MenuItem.where(active: true)
    when "Workspace"
      selectable_workspaces
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def selectable_workspaces
    return Workspace.all if current_user.admin?

    Workspace.where(id: current_user.workspace_id)
  end

  def keep_single_bookmark(bookmarkable)
    return unless bookmarkable.bookmarkable_single?

    current_user.bookmarks.where(bookmarkable_type: bookmarkable.class.base_class.name).destroy_all
  end
end
