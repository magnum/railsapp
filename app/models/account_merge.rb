# frozen_string_literal: true

# Keeps the user identified by the first email:provider pair and attaches the
# second user's identities and records to that user.
class AccountMerge
  PROVIDERS = {
    "google" => "google_oauth2",
    "google_oauth2" => "google_oauth2",
    "microsoft" => "entra_id",
    "entra" => "entra_id",
    "entra_id" => "entra_id",
    "password" => "password"
  }.freeze

  USER_ID_TABLES = %w[
    bookmarks
    pass_keys
    plans
    user_backup_codes
    user_identities
    users_roles
    workspaces
  ].freeze

  def self.parse(spec)
    email, raw_provider = spec.to_s.strip.split(":", 2)
    email = email.to_s.strip.downcase
    provider = PROVIDERS[raw_provider.to_s.strip.downcase]
    if email.blank? || provider.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      raise ArgumentError, "Expected email:provider (google, microsoft, or password), got #{spec.inspect}"
    end

    [ email, provider ]
  end

  def self.call(keeper_spec, source_spec)
    new(keeper_spec, source_spec).call
  end

  def initialize(keeper_spec, source_spec)
    @keeper_email, @keeper_provider = self.class.parse(keeper_spec)
    @source_email, @source_provider = self.class.parse(source_spec)
  end

  def call
    assert_known_user_id_tables!

    ApplicationRecord.transaction do
      @keeper = find_user!(@keeper_email, @keeper_provider)
      @source = find_user!(@source_email, @source_provider)
      raise ArgumentError, "#{@keeper.email} and #{@source.email} are already the same user" if @keeper.id == @source.id

      @keeper.lock!
      @source.lock!
      move_identities
      move_bookmarks
      move_records
      move_roles
      move_api_keys
      move_webhooks
      move_taggings
      retire_source_workspace
      detach_moved_associations
      @source.destroy!
    end

    @keeper
  end

  private

  def assert_known_user_id_tables!
    connection = ApplicationRecord.connection
    unknown = connection.tables.select { |table| connection.column_exists?(table, :user_id) } - USER_ID_TABLES - [ "users" ]
    return if unknown.empty?

    raise "Refusing to merge: user_id on #{unknown.sort.join(', ')} is not handled"
  end

  def find_user!(email, provider)
    user = User.where("LOWER(email) = ?", email).first
    raise ArgumentError, "No user with email #{email}" if user.nil?
    return user if provider_matches?(user, provider)

    linked = ([ user.provider ].compact + user.identities.pluck(:provider)).uniq
    linked << "password" if user.password_digest.present?
    raise ArgumentError, "#{email} is not linked to #{provider}. Linked: #{linked.join(', ')}"
  end

  def provider_matches?(user, provider)
    if provider == "password"
      user.password_digest.present?
    else
      user.provider == provider || user.identities.exists?(provider: provider)
    end
  end

  def move_identities
    if @keeper.password_digest.blank? && @source.password_digest.present?
      @keeper.update!(password_digest: @source.password_digest)
    end
    @keeper.update!(avatar_url: @source.avatar_url) if @keeper.avatar_url.blank? && @source.avatar_url.present?

    @source.identities.update_all(user_id: @keeper.id, updated_at: Time.current)
    if @source.provider.present? && @source.uid.present?
      @keeper.identities.find_or_create_by!(provider: @source.provider, uid: @source.uid)
    end
    @source.update_columns(provider: nil, uid: nil, updated_at: Time.current)
  end

  def move_bookmarks
    Bookmark.where(bookmarkable_type: "User", bookmarkable_id: @source.id).find_each do |bookmark|
      if Bookmark.exists?(user_id: bookmark.user_id, bookmarkable_type: "User", bookmarkable_id: @keeper.id)
        bookmark.delete
      else
        bookmark.update_columns(bookmarkable_id: @keeper.id, updated_at: Time.current)
      end
    end

    Bookmark.where(user_id: @source.id).find_each do |bookmark|
      if Bookmark.exists?(user_id: @keeper.id, bookmarkable_type: bookmark.bookmarkable_type, bookmarkable_id: bookmark.bookmarkable_id)
        bookmark.delete
      else
        bookmark.update_columns(user_id: @keeper.id, updated_at: Time.current)
      end
    end
  end

  def move_records
    now = Time.current
    workspace_id = @keeper.workspace_id
    PassKey.where(user_id: @source.id).update_all(user_id: @keeper.id, updated_at: now)
    Plan.where(user_id: @source.id).update_all(user_id: @keeper.id, workspace_id: workspace_id, updated_at: now)
    keeper_digests = UserBackupCode.where(user_id: @keeper.id).pluck(:code_digest)
    UserBackupCode.where(user_id: @source.id, code_digest: keeper_digests).delete_all
    UserBackupCode.where(user_id: @source.id).update_all(user_id: @keeper.id, updated_at: now)
  end

  def move_roles
    connection = ApplicationRecord.connection
    connection.execute(ApplicationRecord.sanitize_sql_array([
      "DELETE FROM users_roles WHERE user_id = ? AND role_id IN (SELECT role_id FROM users_roles WHERE user_id = ?)",
      @source.id, @keeper.id
    ]))
    connection.execute(ApplicationRecord.sanitize_sql_array([
      "UPDATE users_roles SET user_id = ? WHERE user_id = ?",
      @keeper.id, @source.id
    ]))
  end

  def move_api_keys
    ApiKey.where(bearer_type: "User", bearer_id: @source.id).update_all(
      bearer_id: @keeper.id,
      workspace_id: @keeper.workspace_id,
      updated_at: Time.current
    )
  end

  def move_webhooks
    Webhook.where(webhookable_type: "User", webhookable_id: @source.id).update_all(
      webhookable_id: @keeper.id,
      workspace_id: @keeper.workspace_id,
      updated_at: Time.current
    )
  end

  def move_taggings
    connection = ApplicationRecord.connection
    return unless connection.column_exists?(:taggings, :tagger_id)

    connection.execute(ApplicationRecord.sanitize_sql_array([
      "UPDATE taggings SET tagger_id = ? WHERE tagger_type = 'User' AND tagger_id = ?",
      @keeper.id, @source.id
    ]))
  end

  def retire_source_workspace
    workspace = Workspace.find_by(user_id: @source.id)
    keeper_workspace_id = @keeper.workspace_id
    if workspace.nil? || workspace.id == keeper_workspace_id
      @source.update_columns(workspace_id: nil, updated_at: Time.current)
      return
    end

    now = Time.current
    Plan.where(workspace_id: workspace.id).update_all(workspace_id: keeper_workspace_id, updated_at: now)
    ApiKey.where(workspace_id: workspace.id).update_all(workspace_id: keeper_workspace_id, updated_at: now)
    Webhook.where(workspace_id: workspace.id).update_all(workspace_id: keeper_workspace_id, updated_at: now)
    Invitation.where(workspace_id: workspace.id).update_all(workspace_id: keeper_workspace_id, updated_at: now)
    StaticPage.where(workspace_id: workspace.id).update_all(workspace_id: keeper_workspace_id, updated_at: now)
    User.where(workspace_id: workspace.id).where.not(id: @source.id).update_all(workspace_id: keeper_workspace_id, updated_at: now)
    @source.update_columns(workspace_id: nil, updated_at: now)
    workspace.destroy!
  end

  def detach_moved_associations
    %i[identities bookmarks pass_keys backup_codes plans api_keys webhooks owned_workspace].each do |name|
      @source.association(name).reset
    end
  end
end