# frozen_string_literal: true

class StaticPage < ApplicationRecord
  SLUG_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  include AASM

  validates :slug, presence: true, uniqueness: true, format: { with: SLUG_PATTERN }
  validates :title, presence: true
  validates :state, presence: true

  before_validation :normalize_slug

  after_save :write_locale_template_file, if: :saved_change_to_content?

  aasm column: :state do
    state :created, initial: true
    state :draft
    state :published
  end

  def self.views_path
    Rails.root.join("app/views/static_pages")
  end

  def self.resolve_template(slug, requested_locale = nil)
    return nil unless slug.to_s.match?(SLUG_PATTERN)

    locale = requested_locale.to_s.presence
    default = I18n.default_locale.to_s
    candidates = []
    candidates << locale if locale && available_locale?(locale)
    candidates << default unless candidates.include?(default)
    candidates << nil unless candidates.include?(nil)

    candidates.each do |loc|
      return template_name(slug, loc) if template_file_exists?(slug, loc)
    end

    nil
  end

  def self.template_file_exists?(slug, locale)
    File.file?(template_file_path(slug, locale))
  end

  def self.template_file_path(slug, locale)
    if locale.present?
      views_path.join("#{slug}.#{locale}.html.erb")
    else
      views_path.join("#{slug}.html.erb")
    end
  end

  def self.template_name(slug, locale)
    locale.present? ? "#{slug}.#{locale}" : slug.to_s
  end

  def self.available_locale?(locale)
    I18n.available_locales.map(&:to_s).include?(locale.to_s)
  end

  def published?
    state == "published"
  end

  def visible_to?(user)
    published? || user&.is_editor?
  end

  def load_content_from_file!(locale = I18n.locale)
    template = self.class.resolve_template(slug, locale)
    return unless template

    path = self.class.views_path.join("#{template}.html.erb")
    self.content = File.read(path) if File.file?(path)
  end

  def public_path(locale = I18n.locale)
    locale = locale.to_s
    if locale == I18n.default_locale.to_s
      "/#{slug}"
    else
      "/#{locale}/#{slug}"
    end
  end

  def to_param
    slug
  end

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase if slug.present?
  end

  def write_locale_template_file
    locale = I18n.locale.to_s
    path = self.class.template_file_path(slug, locale)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content.to_s)
  end
end
