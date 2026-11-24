class UserBackupCode < ApplicationRecord
  belongs_to :user

  validates :code_digest, presence: true
end