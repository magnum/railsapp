# frozen_string_literal: true

require "administrate/base_dashboard"

class BookmarkDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    user: Field::BelongsTo,
    bookmarkable: Field::Polymorphic.with_options(classes: [ StaticPage, User, Workspace ]),
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    user
    bookmarkable
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    user
    bookmarkable
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    user
    bookmarkable
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(bookmark)
    "#{bookmark.user&.full_name.presence || bookmark.user&.email} → #{bookmark.bookmarkable_type} ##{bookmark.bookmarkable_id}"
  end
end
