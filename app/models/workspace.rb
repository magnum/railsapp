# frozen_string_literal: true

class Workspace < ApplicationRecord
  belongs_to :user, inverse_of: :owned_workspace

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
    self.name || "Workspace ##{id}"
  end

  private

  def ensure_principal_is_member
    return if user.blank? || user.workspace_id.present?

    user.update_column(:workspace_id, id)
  end
end
