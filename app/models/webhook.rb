# frozen_string_literal: true

class Webhook < ApplicationRecord
  include ValidationSkippable

  belongs_to :webhookable, polymorphic: true

  acts_as_taggable_on :tags

  validates :url, presence: true
  validates :method, presence: true

  include AASM

  after_create_commit do
    call!
  end

  def call!
    async? ? callAsync! : callSync!
  end

  aasm column: :state do
    state :created, initial: true
    state :pending
    state :completed
    state :error

    event :callSync do
      transitions from: [
        :created,
        :error,
        :completed
      ], to: :completed,
      guard: -> {
        doCall!
      }
      error do |e|
        error!(e)
      end
    end

    event :callAsync do
      transitions from: [ :created, :error, :completed ], to: :pending
      before do
        WebhookJob.perform_later(id)
      end
    end

    event :complete do
      transitions to: :completed
      after do
        update_columns(
          error_message: nil,
          error_backtrace: nil
        )
      end
    end

    event :error, after: proc { |e|
      if e.present?
        update_columns(error_message: e&.message, error_backtrace: e&.backtrace&.join("\n"))
      end
    } do
      transitions to: :error
    end

    event :reset do
      transitions to: :created
    end
  end

  def doCall!
    reset_response!
    request_url = url
    request_headers = headers
    request_body = body
    request_method = method
    if ENV["MOCK_WEBHOOKS"] == "true"
      request_url = "https://postman-echo.com/#{request_method.to_s.downcase}"
      request_body = request_body.to_json
      request_headers = (request_headers || {}).merge({
        "Content-Type" => "application/json"
      })
    end
    response = HTTParty.send(
      request_method,
      request_url,
      headers: request_headers,
      body: request_body
    )
    update_columns(
      response_code: response.code,
      response_headers: response.headers.to_h,
      response_body: response.body
    )
    raise "Webhook failed with status #{response.code}" if response.code != 200

    response
  end

  def reset_response!
    update_columns(
      response_code: nil,
      response_headers: nil,
      response_body: nil
    )
  end

  def response_body
    value = read_attribute(:response_body)
    return value if value.blank?

    JSON.pretty_generate(JSON.parse(value))
  rescue JSON::ParserError
    value
  end

  def response_body_json
    JSON.parse(read_attribute(:response_body))
  rescue JSON::ParserError
    nil
  end
end
