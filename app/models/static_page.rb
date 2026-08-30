# frozen_string_literal: true

# Resolves a static page slug to a localized template under app/views/static_pages.
# Files follow Rails locale suffixes, e.g. privacy-policy.en.html.erb.
class StaticPage
  SLUG_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  def initialize(views_path: Rails.root.join("app/views/static_pages"))
    @views_path = Pathname(views_path)
  end

  def resolve_locale(slug, requested_locale = nil)
    return nil unless slug.to_s.match?(SLUG_PATTERN)

    requested = requested_locale.to_s.presence
    default = I18n.default_locale.to_s

    if requested && available_locale?(requested) && exists?(slug, requested)
      return requested
    end

    return default if exists?(slug, default)

    nil
  end

  def exists?(slug, locale)
    Dir.glob(@views_path.join("#{slug}.#{locale}.*")).any? { |path| File.file?(path) }
  end

  private

  def available_locale?(locale)
    I18n.available_locales.map(&:to_s).include?(locale.to_s)
  end
end
