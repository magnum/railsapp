# frozen_string_literal: true

require "test_helper"

class WebhookTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
  end

  test "webhook! sends a sync request and completes" do
    stub_http(code: 200, body: '{"ok":true}') do
      @webhook = @user.webhook!(:post, "https://example.com/hook", body: { hello: "world" }, async: false)
    end

    @webhook.reload
    assert_equal @user, @webhook.webhookable
    assert_equal @user.workspace, @webhook.workspace
    assert_equal "post", @webhook.method
    assert_equal "completed", @webhook.state
    assert_equal 200, @webhook.response_code
    assert_equal({ "ok" => true }, @webhook.response_body_json)
  end

  test "webhook! records an error when the remote status is not 200" do
    stub_http(code: 500, body: '{"ok":false}') do
      @webhook = @user.webhook!(:post, "https://example.com/hook", async: false)
    end

    @webhook.reload
    assert_equal "error", @webhook.state
    assert_equal 500, @webhook.response_code
    assert_match(/500/, @webhook.error_message.to_s)
  end

  test "async webhook! enqueues a job and completes when it runs" do
    assert_enqueued_with(job: WebhookJob) do
      @webhook = @user.webhook!(:post, "https://example.com/hook", async: true)
    end

    assert_equal "pending", @webhook.reload.state

    stub_http(code: 200, body: '{"ok":true}') do
      perform_enqueued_jobs only: WebhookJob
    end

    @webhook.reload
    assert_equal "completed", @webhook.state
    assert_equal 200, @webhook.response_code
  end

  test "requires a url" do
    error = assert_raises(RuntimeError) do
      @user.webhook!(:post, "")
    end
    assert_equal "URL is required", error.message
  end

  private

  def stub_http(code:, body:)
    fake = Module.new
    fake.define_singleton_method(:send) do |*_args, **_kwargs|
      response = Object.new
      response.define_singleton_method(:code) { code }
      response.define_singleton_method(:headers) { { "content-type" => "application/json" } }
      response.define_singleton_method(:body) { body }
      response
    end
    stub_const(Object, :HTTParty, fake) { yield }
  end
end
