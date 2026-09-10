module Admin
  class UsersController < Admin::ApplicationController
    def scoped_resource
      @current_account.users
    end
  end
end
