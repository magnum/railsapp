# frozen_string_literal: true

class BookmarkPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    admin? || own_bookmark?
  end

  def create?
    admin? || own_bookmark?
  end

  def update?
    admin? || own_bookmark?
  end

  def destroy?
    admin? || own_bookmark?
  end

  def own_bookmark?
    return false unless user.present? && record.is_a?(Bookmark)
    return !record.persisted? if record.user_id.blank?

    record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.present?
      return scope.all if user.admin?

      scope.where(user_id: user.id)
    end
  end
end
