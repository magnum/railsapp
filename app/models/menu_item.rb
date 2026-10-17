# frozen_string_literal: true

class MenuItem < ApplicationRecord
  include Bookmarkable

  acts_as_nested_set order_column: :ord, dependent: :destroy

  DEFAULTS = [
    { name: "Pages", link: "/static_pages", ord: 0 },
    { name: "Admin", link: "/admin", ord: 1 },
    { name: "Users", link: "/users", ord: 2 }
  ].freeze

  LABEL_KEYS = {
    "menu" => "menu_items.menu",
    "Pages" => "static_pages.pages_link",
    "Users" => "users.index.title"
  }.freeze

  validates :name, presence: true
  validates :ord, numericality: { only_integer: true }

  before_save :ensure_single_home, if: :is_home?

  def self.home_href_for(user)
    find_by(is_home: true)&.href_for(user).presence
  end

  def self.ensure_defaults!
    menu = find_by(name: "menu") || find_by(name: "Tools") || new
    menu.name = "menu"
    menu.link = nil
    menu.active = true
    menu.ord = 0
    menu.save!

    DEFAULTS.each do |attrs|
      item = find_or_initialize_by(name: attrs[:name])
      item.parent = menu
      item.link = attrs[:link]
      item.ord = attrs[:ord]
      item.active = true
      item.save!
    end
  end

  def label
    key = LABEL_KEYS[name]
    key.present? ? I18n.t(key) : name
  end

  def href_for(_user)
    link.presence
  end

  def visible_to?(user, by_parent = nil)
    return false unless active? && user.present?

    if link.blank?
      kids = by_parent ? Array(by_parent[id]) : children.to_a
      kids.any? { |child| child.visible_to?(user, by_parent) } || user.member_workspaces.exists?
    elsif link.start_with?("/static_pages")
      user.is_editor?
    else
      user.admin?
    end
  end

  private

  def ensure_single_home
    others = self.class.where(is_home: true)
    others = others.where.not(id: id) if persisted?
    others.update_all(is_home: false, updated_at: Time.current)
  end
end
