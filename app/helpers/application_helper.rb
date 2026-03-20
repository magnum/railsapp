module ApplicationHelper
  def google_oauth_configured?
    Rails.application.credentials.dig(:oauth, :google, :client_id).present? &&
      Rails.application.credentials.dig(:oauth, :google, :client_secret).present?
  end
end
