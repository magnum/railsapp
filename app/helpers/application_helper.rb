module ApplicationHelper
  def google_oauth_configured?
    ENV["GOOGLE_CLIENT_ID"].present? &&
      ENV["GOOGLE_CLIENT_SECRET"].present?
  end

  def state_bg_color(state)
    case state.to_s
    when "created", "draft"
      "bg-gray-700"
    when "warning"
      "bg-yellow-500"
    when "running", "processing"
      "bg-blue-700"
    when "completed", "processed", "consumed"
      "bg-green-700"
    when "error"
      "bg-red-700"
    when "canceled", "expired"
      "bg-gray-700"
    else
      "bg-gray-700"
    end
  end

  def state_text_color(state)
    "text-white"
  end

  def badge(state, value = nil)
    content_tag(:span, value || state.to_s.humanize, class: "whitespace-nowrap rounded-md #{state_bg_color(state)} px-2 py-1 text-md font-medium #{state_text_color(state)}")
  end

  def logo_href
    MenuItem.home_href_for(current_user) || root_path
  end

  def menu_items_grouped
    @menu_items_grouped ||= MenuItem.where(active: true).order(:ord, :id).to_a.group_by(&:parent_id)
  end

  def bookmarked_menu_items
    return [] unless current_user

    ids = bookmark_ids_for("MenuItem")
    return [] if ids.empty?

    items = MenuItem.where(id: ids, active: true).index_by(&:id)
    grouped = menu_items_grouped
    ids.filter_map { |id| items[id] }.select { |item| item.visible_to?(current_user, grouped) }
  end

  def member_workspaces_for_menu
    return [] unless current_user

    @member_workspaces_for_menu ||= if current_user.admin?
      Workspace.for_select.to_a
    else
      Array(current_user.workspace)
    end
  end

  def bookmarked?(record)
    return false unless current_user && record

    bookmark_ids_for(record.class.name).include?(record.id)
  end

  def bookmark_ids_for(type)
    @bookmark_ids_for ||= {}
    @bookmark_ids_for[type] ||= current_user.bookmarks.where(bookmarkable_type: type).order(created_at: :desc).pluck(:bookmarkable_id)
  end
end
