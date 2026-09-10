# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end
