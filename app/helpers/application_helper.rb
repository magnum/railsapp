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

  def bookmarked?(record)
    return false unless current_user && record

    bookmark_ids_for(record.class.name).include?(record.id)
  end

  def bookmark_ids_for(type)
    @bookmark_ids_for ||= {}
    @bookmark_ids_for[type] ||= current_user.bookmarks.where(bookmarkable_type: type).order(created_at: :desc).pluck(:bookmarkable_id)
  end
end
