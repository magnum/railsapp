# frozen_string_literal: true

class Account < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :api_keys, dependent: :restrict_with_exception
  has_many :plans, dependent: :restrict_with_exception
  has_many :invitations, dependent: :restrict_with_exception
  has_many :webhooks, dependent: :restrict_with_exception
  has_many :static_pages, dependent: :restrict_with_exception

  validates :name, presence: true
end
