# frozen_string_literal: true

class Account < ApplicationRecord
  belongs_to :user, inverse_of: :owned_account

  has_many :users, dependent: :restrict_with_exception
  has_many :api_keys, dependent: :restrict_with_exception
  has_many :plans, dependent: :restrict_with_exception
  has_many :invitations, dependent: :restrict_with_exception
  has_many :webhooks, dependent: :restrict_with_exception
  has_many :static_pages, dependent: :restrict_with_exception

  after_create :ensure_principal_is_member

  validates :user_id, uniqueness: true

  scope :for_select, -> { includes(:user).order(:id) }

  def display_name
    user&.full_name.presence || user&.email.presence || "Account ##{id}"
  end

  private

  def ensure_principal_is_member
    return if user.blank? || user.account_id.present?

    user.update_column(:account_id, id)
  end
end
