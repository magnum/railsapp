# frozen_string_literal: true

class SessionsController < ApplicationController
  include Authentication
  include InvitationProtected

  before_action :redirect_if_signed_in, only: [:new, :create, :create_magic_link, :magic_link_prompt, :consume_magic_code]

  def new
  end

  def create
    if request.env["omniauth.auth"]
      create_from_oauth
    elsif params[:magic_link].present?
      create_magic_link
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

  def create_magic_link
    unless User.email_magic_link_allowed?
      redirect_to sign_in_path, alert: t("sessions.magic_link_unavailable") and return
    end

    email = params[:email].to_s.strip.downcase
    if email.blank?
      flash.now[:alert] = t("sessions.magic_link_email_required")
      render :new, status: :unprocessable_entity
      return
    end

    User.find_by(email: email)&.send_magic_link
    session[:magic_link_email] = email
    redirect_to sign_in_magic_link_prompt_path, notice: t("sessions.magic_link_sent"), status: :see_other
  end

  def magic_link_prompt
    unless User.email_magic_link_allowed?
      redirect_to sign_in_path, alert: t("sessions.magic_link_unavailable") and return
    end

    @email = session[:magic_link_email]
  end

  def consume_magic_link
    user = User.consume_magic_link(params[:token])
    if user
      sign_in_user(user)
    else
      redirect_to sign_in_path, alert: t("sessions.magic_link_invalid")
    end
  end

  def consume_magic_code
    unless User.email_magic_link_allowed?
      redirect_to sign_in_path, alert: t("sessions.magic_link_unavailable") and return
    end

    user = User.consume_magic_code(params[:code])
    if user
      sign_in_user(user)
    else
      redirect_to sign_in_magic_link_prompt_path, alert: t("sessions.magic_code_invalid"), status: :see_other
    end
  end

  private

  def sign_in_user(user)
    session.delete(:magic_link_email)
    session[:user_id] = user.id
    redirect_to root_path, notice: t("sessions.signed_in")
  end

  def create_from_oauth
    unless Settings.auth.allow_connect_google
      redirect_to sign_in_path, alert: t("sessions.oauth_failure") and return
    end

    auth = request.env["omniauth.auth"]
    existing_user = User.find_for_omniauth(auth)

    if existing_user.nil?
      invitation = current_invitation
      unless invitation&.consumable?
        redirect_to root_path, alert: t("views.invitations.requires_invitation") and return
      end
    end

    user = User.from_omniauth(auth, workspace: current_invitation&.workspace)
    session[:user_id] = user.id

    invitation = current_invitation
    invitation.consume! if invitation&.may_consume? && existing_user.nil?

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
