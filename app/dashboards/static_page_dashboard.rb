# frozen_string_literal: true

require "administrate/base_dashboard"

class StaticPageDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    slug: Field::String,
    title: Field::String,
    state: Field::Aasm.with_options(searchable: true, searchable_field: :name),
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    content: Field::Text
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    slug
    title
    state
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    slug
    title
    state
    content
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    slug
    title
    state
    content
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(static_page)
    static_page.title
  end
end
