# frozen_string_literal: true

require "administrate/base_dashboard"

class MenuItemDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    link: Field::String,
    active: Field::Boolean,
    is_home: Field::Boolean,
    ord: Field::Number,
    parent: Field::BelongsTo.with_options(class_name: "MenuItem"),
    children: Field::HasMany.with_options(class_name: "MenuItem"),
    bookmarks: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    name
    link
    parent
    ord
    active
    is_home
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    link
    active
    is_home
    ord
    parent
    children
    bookmarks
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    name
    link
    active
    is_home
    ord
    parent
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(menu_item)
    menu_item.name
  end
end
