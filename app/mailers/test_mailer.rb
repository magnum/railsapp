class TestMailer < ApplicationMailer
  def test_message(email_to, text)
    @text = text
    mail to: email_to, subject: t("test_mailer.subject", app: Settings.app.name)
  end
end
