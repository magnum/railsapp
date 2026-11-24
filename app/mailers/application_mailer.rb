class ApplicationMailer < ActionMailer::Base
  default from: -> { self.class.sender_address }
  layout "mailer"

  def self.sender_address
    Settings.app.email
  end
end
