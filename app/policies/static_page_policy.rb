# frozen_string_literal: true

class StaticPagePolicy < ApplicationPolicy
  def index?
    editor?
  end

  def show?
    record.visible_to?(user)
  end

  def create?
    editor?
  end

  def new?
    create?
  end

  def update?
    editor?
  end

  def edit?
    update?
  end

  def destroy?
    editor?
  end

  class Scope < Scope
    def resolve
      if user&.is_editor?
        scope.all
      else
        scope.where(state: "published")
      end
    end
  end

  private

  def editor?
    user.present? && user.is_editor?
  end
end
