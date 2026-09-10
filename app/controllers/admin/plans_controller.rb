module Admin
  class PlansController < Admin::ApplicationController
    def scoped_resource
      @current_account.plans
    end
  end
end
