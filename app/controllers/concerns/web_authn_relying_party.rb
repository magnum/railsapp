# frozen_string_literal: true

module WebAuthnRelyingParty
  extend ActiveSupport::Concern

  private

  def relying_party
    @relying_party ||= WebAuthn::RelyingParty.new(
      allowed_origins: [ request.base_url ],
      name: Settings.app.name,
      id: request.host
    )
  end
end