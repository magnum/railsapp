module Admin
  class InvitationsController < Admin::ApplicationController
    def scoped_resource
      @current_workspace.invitations
    end
  end
end
