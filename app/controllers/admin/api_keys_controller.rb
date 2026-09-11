module Admin
  class ApiKeysController < Admin::ApplicationController
    def scoped_resource
      @current_workspace.api_keys
    end
  end
end
