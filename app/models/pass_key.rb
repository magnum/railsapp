class PassKey < ApplicationRecord
  belongs_to :user

  attr_accessor :credential, :webauthn_challenge, :relying_party

  validates :name, presence: true
  validates :external_id, :public_key, presence: true
  validates :external_id, uniqueness: true

  before_validation :consume_credential, on: :create

  private

  def consume_credential
    return if external_id.present? && public_key.present?
    return errors.add(:base, :invalid_credential) if credential.blank? || webauthn_challenge.blank? || relying_party.blank?

    raw = credential.is_a?(String) ? JSON.parse(credential) : credential
    verified = relying_party.verify_registration(raw, webauthn_challenge)
    return errors.add(:base, :invalid_credential) unless verified

    self.external_id = verified.id
    self.public_key = verified.public_key
    self.sign_count = verified.sign_count
  rescue JSON::ParserError, WebAuthn::Error, ArgumentError, RuntimeError => error
    Rails.logger.warn("Passkey registration failed: #{error.class}: #{error.message}")
    errors.add(:base, :invalid_credential)
  end
end