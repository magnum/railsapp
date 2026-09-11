module Admin
  class UsersController < Admin::ApplicationController
    def scoped_resource
      @current_workspace.users
    end
  end
end
