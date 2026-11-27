# frozen_string_literal: true

google_client_id = ENV["GOOGLE_CLIENT_ID"]
google_client_secret = ENV["GOOGLE_CLIENT_SECRET"]
microsoft_client_id = ENV["MICROSOFT_CLIENT_ID"]
microsoft_client_secret = ENV["MICROSOFT_CLIENT_SECRET"]

google_oauth = google_client_id.present? && google_client_secret.present?
microsoft_oauth = microsoft_client_id.present? && microsoft_client_secret.present?

if google_oauth || microsoft_oauth
  Rails.application.config.middleware.use OmniAuth::Builder do
    if google_oauth
      provider :google_oauth2, google_client_id, google_client_secret
    end

    if microsoft_oauth
      # tenant "common" accepts personal Microsoft accounts and work or school accounts.
      provider :entra_id, {
        client_id: microsoft_client_id,
        client_secret: microsoft_client_secret,
        tenant_id: "common"
      }
    end
  end
end

OmniAuth.config.allowed_request_methods = [ :get, :post ]
