# frozen_string_literal: true

module CurrentAccount
  extend ActiveSupport::Concern

  included do
    before_action :set_current_account
    helper_method :current_account
  end

  private

  def current_account
    @current_account
  end

  def set_current_account
    return unless current_user

    if current_user.admin? && session[:selected_account_id].present?
      @current_account = Account.find_by(id: session[:selected_account_id])
    end

    @current_account ||= current_user.account
    Current.account = @current_account
  end
end
