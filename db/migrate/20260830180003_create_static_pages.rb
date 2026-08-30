# frozen_string_literal: true

class CreateStaticPages < ActiveRecord::Migration[8.1]
  class MigrationStaticPage < ApplicationRecord
    self.table_name = "static_pages"
  end

  VIEWS_PATH = Rails.root.join("app/views/static_pages")

  PAGES = [
    { slug: "cookie-policy", title: "Cookie Policy", source: "cookie-policy.en.html.erb" },
    { slug: "privacy-policy", title: "Privacy Policy", source: "privacy-policy.en.html.erb" },
    { slug: "terms-and-conditions", title: "Terms and Conditions", source: "terms-and-conditions.en.html.erb" },
    {
      slug: "404",
      title: "Not Found",
      content: <<~ERB
        <% content_for :title, "Not Found" %>

        <article class="prose prose-gray mx-auto">
          <p>content not found, <a href="/">back to the homepage</a></p>
        </article>
      ERB
    },
    {
      slug: "test",
      title: "Test",
      content: <<~ERB
        <% content_for :title, "Test" %>

        <article class="prose prose-gray mx-auto">
          <p>this is a test page</p>
        </article>
      ERB
    }
  ].freeze

  def up
    create_table :static_pages do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.text :content
      t.string :state, null: false, default: "created"
      t.timestamps
    end

    add_index :static_pages, :slug, unique: true

    PAGES.each do |attrs|
      content = attrs[:content] || File.read(VIEWS_PATH.join(attrs[:source]))
      MigrationStaticPage.create!(
        slug: attrs[:slug],
        title: attrs[:title],
        content: content,
        state: "published"
      )

      next if attrs[:source]

      write_template_file(attrs[:slug], "en", content)
    end

    add_editor_role_to_users
  end

  def down
    drop_table :static_pages
  end

  private

  def write_template_file(slug, locale, content)
    FileUtils.mkdir_p(VIEWS_PATH)
    File.write(VIEWS_PATH.join("#{slug}.#{locale}.html.erb"), content)
  end

  def add_editor_role_to_users
    return unless table_exists?(:users)

    now = connection.quote(Time.current)
    execute <<~SQL.squish
      INSERT INTO roles (name, created_at, updated_at)
      SELECT 'editor', #{now}, #{now}
      WHERE NOT EXISTS (SELECT 1 FROM roles WHERE name = 'editor' AND resource_type IS NULL AND resource_id IS NULL)
    SQL

    execute <<~SQL.squish
      INSERT INTO users_roles (user_id, role_id)
      SELECT users.id, roles.id
      FROM users
      CROSS JOIN roles
      WHERE roles.name = 'editor'
        AND roles.resource_type IS NULL
        AND roles.resource_id IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM users_roles
          WHERE users_roles.user_id = users.id AND users_roles.role_id = roles.id
        )
    SQL
  end
end
