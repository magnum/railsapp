# frozen_string_literal: true

class StaticPagesController < ApplicationController
  layout "application"
  skip_before_action :set_locale

  def show
    slug = params[:slug].to_s
    requested = params[:locale].presence || session[:locale].presence
    locale = StaticPage.new.resolve_locale(slug, requested)

    unless locale
      return render file: Rails.root.join("public/404.html"), layout: false, status: :not_found
    end

    I18n.locale = locale
    render template: "static_pages/#{slug}", formats: [ :html ]
  end

  private

  def skip_modern_browser_check?
    true
  end
end
