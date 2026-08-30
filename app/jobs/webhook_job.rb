# frozen_string_literal: true

class WebhookJob < ApplicationJob
  queue_as :webhooks

  def perform(id)
    webhook = Webhook.find(id)
    webhook.doCall!
    webhook.complete!
  rescue => e
    webhook.error!(e)
    raise e
  end
end
