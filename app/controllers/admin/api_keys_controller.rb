module Admin
  class ApiKeysController < Admin::ApplicationController
    def scoped_resource
      @current_account.api_keys
    end
  end
end
