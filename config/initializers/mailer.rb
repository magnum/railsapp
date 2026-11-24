# frozen_string_literal: true

smtp = Rails.application.credentials.dig(:smtp)
return if smtp.blank? || Rails.env.test?

settings = {
  address: smtp[:host],
  port: smtp[:port].to_i,
  user_name: smtp[:username],
  password: smtp[:password],
  authentication: :login,
  enable_starttls_auto: true
}

Rails.application.config.action_mailer.delivery_method = :smtp
Rails.application.config.action_mailer.perform_deliveries = true
Rails.application.config.action_mailer.raise_delivery_errors = true
Rails.application.config.action_mailer.smtp_settings = settings

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.smtp_settings = settings
