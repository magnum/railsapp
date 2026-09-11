# frozen_string_literal: true

require "administrate/base_dashboard"

class WorkspaceDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    user: Field::BelongsTo,
    users: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    name
    user
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    user
    users
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    name
    user
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(workspace)
    workspace.display_name
  end
end
