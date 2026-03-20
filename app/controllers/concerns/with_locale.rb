# frozen_string_literal: true

module WithLocale
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private

  def set_locale
    I18n.locale = params[:locale] || session[:locale] || I18n.default_locale
  end
end
