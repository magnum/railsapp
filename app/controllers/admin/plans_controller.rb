module Admin
  class PlansController < Admin::ApplicationController
    def scoped_resource
      @current_workspace.plans
    end
  end
end
