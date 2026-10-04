# frozen_string_literal: true

require "test_helper"

class WebhookJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "completes the webhook after a successful call" do
    webhook = Webhook.create!(
      webhookable: @user,
      workspace: @user.workspace,
      method: "post",
      url: "https://example.com/hook",
      async: true
    )

    fake = Module.new
    fake.define_singleton_method(:send) do |*_args, **_kwargs|
      response = Object.new
      response.define_singleton_method(:code) { 200 }
      response.define_singleton_method(:headers) { {} }
      response.define_singleton_method(:body) { '{"ok":true}' }
      response
    end

    stub_const(Object, :HTTParty, fake) do
      WebhookJob.perform_now(webhook.id)
    end

    webhook.reload
    assert_equal "completed", webhook.state
    assert_nil webhook.error_message
  end
end
