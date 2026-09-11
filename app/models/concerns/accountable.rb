# frozen_string_literal: true

module Accountable
  extend ActiveSupport::Concern

  included do
    belongs_to :account, optional: name == "User"
  end
end
