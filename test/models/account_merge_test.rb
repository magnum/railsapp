# frozen_string_literal: true

require "test_helper"
require "rake"

class AccountMergeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("railsapp:merge_account_emails")
    Rake::Task["railsapp:merge_account_emails"].reenable
  end

  test "keeps the first user and moves the second user's identity, plans, and passkeys" do
    keeper = build_user("keeper@gmail.com", "google_oauth2", "google-uid")
    source = build_user("source@outlook.com", "entra_id", "microsoft-uid")
    source.add_role(:editor)
    plan = source.plans.create!(
      plan_type: plan_types(:one),
      workspace: source.workspace,
      valid_from: Date.current,
      valid_to: Date.current + 1
    )
    pass_key = source.pass_keys.build(name: "Phone", external_id: "merge-passkey", public_key: "pk", sign_count: 0)
    pass_key.save!(validate: false)

    merged = AccountMerge.call("#{keeper.email}:google", "#{source.email}:microsoft")

    assert_equal keeper, merged
    assert_nil User.find_by(email: "source@outlook.com")
    assert_equal [ "entra_id", "google_oauth2" ], keeper.identities.order(:provider).pluck(:provider)
    assert_equal keeper, plan.reload.user
    assert_equal keeper.workspace_id, plan.workspace_id
    assert_equal keeper, pass_key.reload.user
    assert keeper.has_role?(:editor)
    assert_equal keeper, User.find_for_omniauth(microsoft_auth(source.email))
    assert keeper.authenticate("password1")
  end

  test "refuses a provider that is not linked to that email" do
    keeper = build_user("keeper@gmail.com", "google_oauth2", "google-uid")
    source = build_user("source@outlook.com", "entra_id", "microsoft-uid")

    error = assert_raises(ArgumentError) do
      AccountMerge.call("#{keeper.email}:microsoft", "#{source.email}:entra_id")
    end

    assert_match "not linked to entra_id", error.message
    assert User.exists?(source.id)
  end

  test "rake task waits for confirmation" do
    keeper = build_user("keeper@gmail.com", "google_oauth2", "google-uid")
    source = build_user("source@outlook.com", "entra_id", "microsoft-uid")
    stdin = StringIO.new("no\n")

    previous = $stdin
    $stdin = stdin
    assert_raises(SystemExit) do
      Rake::Task["railsapp:merge_account_emails"].invoke("#{keeper.email}:google_oauth2", "#{source.email}:microsoft")
    end

    assert User.exists?(source.id)
  ensure
    $stdin = previous
  end

  private

  def build_user(email, provider, uid)
    user = User.create!(
      firstname: "Ada",
      lastname: "Lovelace",
      email: email,
      password: "password1",
      password_confirmation: "password1"
    )
    user.update!(provider: provider, uid: uid)
    user.identities.create!(provider: provider, uid: uid)
    user
  end

  def microsoft_auth(email)
    OmniAuth::AuthHash.new(
      provider: "entra_id",
      uid: "microsoft-uid",
      info: { email: email, name: "Ada Lovelace" }
    )
  end
end