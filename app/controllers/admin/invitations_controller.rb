module Admin
  class InvitationsController < Admin::ApplicationController
    def scoped_resource
      @current_account.invitations
    end
  end
end
