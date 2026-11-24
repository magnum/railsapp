# frozen_string_literal: true

require "test_helper"

module Test
  class EmailsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @admin.update!(password: "password1", password_confirmation: "password1")
      @member = users(:two)
      @member.update!(password: "password1", password_confirmation: "password1")
      ActionMailer::Base.deliveries.clear
    end

    test "guest is sent to sign in" do
      get test_email_path

      assert_redirected_to sign_in_path
    end

    test "non-admin cannot open the form or send" do
      sign_in_as(@member)

      get test_email_path
      assert_redirected_to root_path

      assert_no_difference "ActionMailer::Base.deliveries.size" do
        post test_email_path, params: { email_to: "dest@example.com", text: "ciao" }
      end
      assert_redirected_to root_path
    end

    test "admin sees the form" do
      @admin.add_role(:admin)
      sign_in_as(@admin)

      get test_email_path

      assert_response :success
      assert_select "form[action=?]", test_email_path
      assert_select "input[name=email_to]"
      assert_select "textarea[name=text]"
      assert_select "form[data-turbo-confirm=?]", I18n.t("test_email.confirm")
    end

    test "admin sends the email" do
      @admin.add_role(:admin)
      sign_in_as(@admin)

      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        post test_email_path, params: { email_to: "dest@example.com", text: "ciao" }
      end

      assert_redirected_to test_email_path
      mail = ActionMailer::Base.deliveries.last
      assert_equal [ "dest@example.com" ], mail.to
      assert_equal [ Settings.app.email ], mail.from
      assert_includes mail.body.encoded, "ciao"
    end

    test "admin cannot send an invalid address" do
      @admin.add_role(:admin)
      sign_in_as(@admin)

      assert_no_difference "ActionMailer::Base.deliveries.size" do
        post test_email_path, params: { email_to: "not-an-email", text: "ciao" }
      end

      assert_redirected_to test_email_path
      assert_equal I18n.t("test_email.invalid"), flash[:alert]
    end

    private

    def sign_in_as(user)
      post sign_in_path, params: { email: user.email, password: "password1" }
    end
  end
end
