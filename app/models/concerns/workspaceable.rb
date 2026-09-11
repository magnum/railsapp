# frozen_string_literal: true

module Workspaceable
  extend ActiveSupport::Concern

  included do
    belongs_to :workspace, optional: name == "User"
  end
end
