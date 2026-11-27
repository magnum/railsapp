# frozen_string_literal: true

class UserIdentity < ApplicationRecord
  PROVIDERS = %w[google_oauth2 entra_id].freeze

  belongs_to :user

  validates :provider, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }
end