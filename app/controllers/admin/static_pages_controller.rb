# frozen_string_literal: true

module Admin
  class StaticPagesController < Admin::ApplicationController
    def find_resource(param)
      StaticPage.find_by!(slug: param)
    end

    def edit
      requested_resource.load_content_from_file!
      super
    end

    private

    # Administrate looks up resources via params[:id]; our routes use :slug.
    def requested_resource
      @requested_resource ||= find_resource(params[:slug]).tap do |resource|
        authorize_resource(resource)
      end
    end
  end
end
