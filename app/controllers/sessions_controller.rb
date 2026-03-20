# frozen_string_literal: true

class SessionsController < ApplicationController
  include Authentication

  before_action :redirect_if_signed_in, only: [:new, :create]

  def new
  end

  def create
    if request.env["omniauth.auth"]
      create_from_oauth
    else
      create_from_password
    end
  end

  def destroy
    reset_session
    redirect_to sign_in_path, notice: t("sessions.signed_out")
  end

  def failure
    redirect_to sign_in_path, alert: t("sessions.oauth_failure")
  end

  private

  def create_from_oauth
    user = User.from_omniauth(request.env["omniauth.auth"])
    session[:user_id] = user.id
    redirect_to root_path, notice: t("sessions.signed_in")
  end

  def create_from_password
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path, notice: t("sessions.signed_in")
    else
      flash.now[:alert] = t("sessions.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end
end
