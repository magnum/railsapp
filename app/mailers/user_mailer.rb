class UserMailer < ApplicationMailer
  def magic_link(user, token, code)
    @user = user
    @url = consume_sign_in_magic_link_url(token)
    @code = code
    mail to: user.email, subject: t("user_mailer.magic_link.subject", app: Settings.app.name)
  end
end