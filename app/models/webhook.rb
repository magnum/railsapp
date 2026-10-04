# frozen_string_literal: true

require "httparty"

class Webhook < ApplicationRecord
  include Workspaceable
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
    request_headers = normalize_headers(headers)
    request_body = normalize_body(body)
    request_method = method.to_s.downcase
    if ENV["MOCK_WEBHOOKS"] == "true"
      request_url = "https://postman-echo.com/#{request_method}"
      request_body = request_body.is_a?(String) ? request_body : request_body.to_json
      request_headers = request_headers.merge("Content-Type" => "application/json")
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
  rescue JSON::ParserError, TypeError
    nil
  end

  private

  def normalize_headers(value)
    parsed = parse_jsonish(value)
    return {} unless parsed.is_a?(Hash)

    parsed.stringify_keys
  end

  def normalize_body(value)
    parse_jsonish(value)
  end

  def parse_jsonish(value)
    case value
    when String
      stripped = value.strip
      return value if stripped.blank?

      JSON.parse(stripped)
    when Hash
      value
    else
      value
    end
  rescue JSON::ParserError
    value
  end
end
