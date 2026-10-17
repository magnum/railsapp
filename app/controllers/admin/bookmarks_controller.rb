# frozen_string_literal: true

module Admin
  class BookmarksController < Admin::ApplicationController
    def scoped_resource
      policy_scope(Bookmark.where(user_id: @current_workspace.users.select(:id)))
    end

    def resource_params
      permitted = super
      return permitted if current_user&.admin?

      permitted[:user_id] = current_user.id
      permitted
    end

    def default_sorting_attribute
      :created_at
    end

    def default_sorting_direction
      :desc
    end
  end
end
