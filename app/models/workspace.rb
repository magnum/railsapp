# frozen_string_literal: true

class Workspace < ApplicationRecord
  belongs_to :user, inverse_of: :owned_workspace

  has_many :users, dependent: :restrict_with_exception
  has_many :api_keys, dependent: :restrict_with_exception
  has_many :plans, dependent: :restrict_with_exception
  has_many :invitations, dependent: :restrict_with_exception
  has_many :webhooks, dependent: :restrict_with_exception
  has_many :static_pages, dependent: :restrict_with_exception

  before_validation :assign_default_name, on: :create
  after_create :ensure_principal_is_member

  validates :user_id, uniqueness: true
  validates :name, presence: true

  scope :for_select, -> { order(:id) }

  def display_name
    "#{id} - #{name}".truncate(20, omission: "...")
  end

  private

  def assign_default_name
    self.name = "My Workspace" if name.blank?
  end

  def ensure_principal_is_member
    return if user.blank? || user.workspace_id.present?

    user.update_column(:workspace_id, id)
  end
end
