require "digest"
require "rotp"
require "rqrcode"

module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  BACKUP_CODE_COUNT = 10
  BACKUP_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  BACKUP_CODE_LENGTH = 8

  included do
    has_many :backup_codes, class_name: "UserBackupCode", dependent: :destroy
  end

  class_methods do
    def two_factor_required_for_all?
      auth_flag("2fa_required")
    end

    def two_factor_required_for_admins?
      auth_flag("2fa_required_for_admin")
    end

    def auth_flag(key)
      ActiveModel::Type::Boolean.new.cast(Settings.auth[key])
    end

    def generate_backup_code
      Array.new(BACKUP_CODE_LENGTH) { BACKUP_CODE_ALPHABET[SecureRandom.random_number(BACKUP_CODE_ALPHABET.length)] }.join
    end

    def format_backup_code(code)
      "#{code[0, 4]}-#{code[4, 4]}"
    end

    def normalize_backup_code(code)
      code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    end
  end

  def two_factor_active?
    otp_enabled_at.present? && otp_secret.present?
  end

  def two_factor_required?
    self.class.two_factor_required_for_all? || (admin? && self.class.two_factor_required_for_admins?)
  end

  def two_factor_setup_required?
    two_factor_required? && !two_factor_active?
  end

  def two_factor_pending?
    otp_pending_secret.present? && otp_enabled_at.blank?
  end

  def start_two_factor_setup!
    update!(otp_pending_secret: ROTP::Base32.random)
  end

  def otp_provisioning_uri
    return if otp_pending_secret.blank?

    ROTP::TOTP.new(otp_pending_secret, issuer: Settings.app.name).provisioning_uri(email)
  end

  def otp_qr_svg
    svg = RQRCode::QRCode.new(otp_provisioning_uri).as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    )
    svg.sub(/\A<\?xml.*?\?>\s*/m, "").html_safe
  end

  def formatted_otp_pending_secret
    otp_pending_secret.to_s.scan(/.{1,4}/).join(" ")
  end

  def confirm_two_factor!(code)
    return if otp_pending_secret.blank?

    timestamp = totp_for(otp_pending_secret).verify(normalize_otp_code(code), drift_behind: 30, drift_ahead: 30)
    return unless timestamp

    plaintext = Array.new(BACKUP_CODE_COUNT) { self.class.format_backup_code(self.class.generate_backup_code) }
    transaction do
      backup_codes.delete_all
      plaintext.each do |backup|
        backup_codes.create!(code_digest: Digest::SHA256.hexdigest(self.class.normalize_backup_code(backup)))
      end
      self.otp_secret = otp_pending_secret
      self.otp_pending_secret = nil
      self.otp_enabled_at = Time.current
      self.otp_last_used_at = Time.zone.at(timestamp)
      save!
    end
    plaintext
  end

  def disable_two_factor!
    transaction do
      backup_codes.delete_all
      update!(
        otp_secret: nil,
        otp_pending_secret: nil,
        otp_enabled_at: nil,
        otp_last_used_at: nil
      )
    end
  end

  def authenticate_two_factor!(code)
    compact = code.to_s.gsub(/[\s-]/, "")
    if compact.match?(/\A\d{6}\z/)
      verify_totp!(compact)
    else
      consume_backup_code!(compact)
    end
  end

  def otp_secret
    decrypt_otp(otp_secret_ciphertext)
  end

  def otp_secret=(value)
    self.otp_secret_ciphertext = encrypt_otp(value)
  end

  def otp_pending_secret
    decrypt_otp(otp_pending_secret_ciphertext)
  end

  def otp_pending_secret=(value)
    self.otp_pending_secret_ciphertext = encrypt_otp(value)
  end

  private

  def verify_totp!(code)
    return false if otp_secret.blank?

    options = { drift_behind: 30, drift_ahead: 30 }
    options[:after] = otp_last_used_at.to_i if otp_last_used_at.present?
    timestamp = totp_for(otp_secret).verify(code, **options)
    return false unless timestamp

    update_columns(otp_last_used_at: Time.zone.at(timestamp), updated_at: Time.current)
    true
  end

  def consume_backup_code!(code)
    digest = Digest::SHA256.hexdigest(self.class.normalize_backup_code(code))
    backup_codes.where(code_digest: digest).delete_all == 1
  end

  def totp_for(secret)
    ROTP::TOTP.new(secret, issuer: Settings.app.name)
  end

  def normalize_otp_code(code)
    code.to_s.gsub(/\s/, "")
  end

  def encrypt_otp(value)
    return if value.blank?

    otp_encryptor.encrypt_and_sign(value)
  end

  def decrypt_otp(ciphertext)
    return if ciphertext.blank?

    otp_encryptor.decrypt_and_verify(ciphertext)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def otp_encryptor
    secret = Rails.application.key_generator.generate_key("user-otp-secret", 32)
    ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm")
  end
end
