# frozen_string_literal: true

class SessionsController < ApplicationController
  include Authentication
  include InvitationProtected
  include WebAuthnRelyingParty

  before_action :redirect_if_signed_in, only: [:new, :create, :create_magic_link, :magic_link_prompt, :consume_magic_code, :two_factor, :create_two_factor, :passkey_options, :create_passkey]

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

  def two_factor
    @user = pending_two_factor_user
    if @user.nil?
      redirect_to sign_in_path, alert: t("sessions.two_factor_expired")
      return
    end

    return unless @user.two_factor_locked?

    clear_pending_two_factor
    redirect_to sign_in_path, alert: t("sessions.two_factor_locked")
  end

  def passkey_options
    authentication = relying_party.options_for_authentication(user_verification: "preferred")
    session[:webauthn_authentication_challenge] = authentication.challenge
    render json: authentication
  end

  def create_passkey
    user = user_from_passkey
    if user
      sign_in_user(user)
    else
      redirect_to sign_in_path, alert: t("sessions.passkey_invalid"), status: :see_other
    end
  end

  def create_two_factor
    @user = pending_two_factor_user
    if @user.nil?
      redirect_to sign_in_path, alert: t("sessions.two_factor_expired")
      return
    end

    if @user.two_factor_locked?
      clear_pending_two_factor
      redirect_to sign_in_path, alert: t("sessions.two_factor_locked"), status: :see_other
      return
    end

    if @user.authenticate_two_factor!(params[:otp_code])
      @user.clear_two_factor_failures!
      clear_pending_two_factor
      session[:user_id] = @user.id
      redirect_to root_path, notice: t("sessions.signed_in"), status: :see_other
    elsif @user.register_two_factor_failure!
      clear_pending_two_factor
      redirect_to sign_in_path, alert: t("sessions.two_factor_locked"), status: :see_other
    else
      flash.now[:alert] = t("sessions.two_factor_invalid")
      render :two_factor, status: :unprocessable_entity
    end
  end

  private

  def sign_in_user(user)
    session.delete(:magic_link_email)
    clear_pending_two_factor
    if user.two_factor_active?
      if user.two_factor_locked?
        redirect_to sign_in_path, alert: t("sessions.two_factor_locked"), status: :see_other
      else
        session[:pending_2fa_user_id] = user.id
        session[:pending_2fa_at] = Time.current.to_i
        redirect_to sign_in_two_factor_path, status: :see_other
      end
    else
      session[:user_id] = user.id
      if user.two_factor_setup_required?
        redirect_to user_path(user), alert: t("users.two_factor.setup_required"), status: :see_other
      else
        redirect_to root_path, notice: t("sessions.signed_in"), status: :see_other
      end
    end
  end

  def pending_two_factor_user
    return if session[:pending_2fa_user_id].blank?

    started_at = Time.zone.at(session[:pending_2fa_at].to_i)
    if started_at < 10.minutes.ago
      clear_pending_two_factor
      return
    end

    user = User.find_by(id: session[:pending_2fa_user_id])
    return user if user&.two_factor_active?

    clear_pending_two_factor
    nil
  end

  def clear_pending_two_factor
    session.delete(:pending_2fa_user_id)
    session.delete(:pending_2fa_at)
  end

  def user_from_passkey
    challenge = session.delete(:webauthn_authentication_challenge)
    return if challenge.blank?

    raw = params[:credential]
    raw = JSON.parse(raw) if raw.is_a?(String)
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    webauthn_credential = WebAuthn::Credential.from_get(raw, relying_party: relying_party)
    pass_key = PassKey.find_by(external_id: webauthn_credential.id)
    unless pass_key
      Rails.logger.warn("Passkey sign-in: no credential #{webauthn_credential.id}")
      return
    end

    webauthn_credential.verify(
      challenge,
      public_key: pass_key.public_key,
      sign_count: pass_key.sign_count
    )
    pass_key.update!(sign_count: webauthn_credential.sign_count, last_used_at: Time.current)
    pass_key.user
  rescue JSON::ParserError, WebAuthn::Error, ArgumentError, RuntimeError, NoMethodError, TypeError => error
    Rails.logger.warn("Passkey sign-in failed: #{error.class}: #{error.message}")
    nil
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

    invitation = current_invitation
    invitation.consume! if invitation&.may_consume? && existing_user.nil?

    sign_in_user(user)
  end

  def create_from_password
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params[:password])
      sign_in_user(user)
    else
      flash.now[:alert] = t("sessions.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end
end
