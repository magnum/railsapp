# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    user.present? && (admin? || record == user)
  end

  def create?
    admin?
  end

  def new?
    admin?
  end

  def update?
    user.present? && (admin? || record == user)
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  def manage_two_factor?
    user.present? && record == user
  end

  def manage_pass_keys?
    user.present? && record == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.admin? ? scope.all : scope.where(id: user.id)
    end
  end
end
