# frozen_string_literal: true

google_client_id = Rails.application.credentials.dig(:oauth, :google, :client_id)
google_client_secret = Rails.application.credentials.dig(:oauth, :google, :client_secret)

if google_client_id.present? && google_client_secret.present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, google_client_id, google_client_secret
  end
end

OmniAuth.config.allowed_request_methods = [:get, :post]
