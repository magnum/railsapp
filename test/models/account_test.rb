# frozen_string_literal: true

require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "is valid with a name" do
    account = Account.new(name: "Acme")
    assert account.valid?
  end

  test "requires a name" do
    account = Account.new(name: "")
    assert_not account.valid?
  end
end
