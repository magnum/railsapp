class User < ApplicationRecord
  include Workspaceable
  include ApiKeyable
  include Plannable
  include Webhookable

  has_one :owned_workspace, class_name: "Workspace", inverse_of: :user, dependent: :restrict_with_exception
  has_many :bookmarks, dependent: :destroy
  has_many :received_bookmarks, class_name: "Bookmark", as: :bookmarkable, dependent: :destroy

  rolify
  has_secure_password validations: false

  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: false
  validates :firstname, :lastname, presence: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :password_or_oauth
  validate :password_confirmation_match, if: -> { password.present? }

  after_create :ensure_owned_workspace, :create_default_plan

  def self.find_for_omniauth(auth)
    find_by(provider: auth.provider, uid: auth.uid) || find_by_omniauth_email(auth)
  end

  def self.from_omniauth(auth, workspace: nil)
    user = find_for_omniauth(auth) || new
    previously_linked = user.persisted? && user.provider == auth.provider

    if user.new_record?
      user.email = auth.info.email
      user.firstname = omniauth_firstname(auth)
      user.lastname = omniauth_lastname(auth)
      user.workspace = workspace if workspace
    elsif previously_linked
      user.email = auth.info.email if auth.info.email.present?
      user.firstname = omniauth_firstname(auth)
      user.lastname = omniauth_lastname(auth)
    end

    if auth.info.image.present? && (user.new_record? || previously_linked || user.avatar_url.blank?)
      user.avatar_url = auth.info.image
    end

    user.provider = auth.provider
    user.uid = auth.uid
    user.save!
    user
  end

  def self.find_by_omniauth_email(auth)
    email = auth.info.email.to_s.strip.downcase
    return if email.blank?

    where("LOWER(email) = ?", email).first
  end
  private_class_method :find_by_omniauth_email

  def self.omniauth_firstname(auth)
    auth.info.first_name.presence || auth.info.name&.split&.first || "User"
  end
  private_class_method :omniauth_firstname

  def self.omniauth_lastname(auth)
    auth.info.last_name.presence || auth.info.name&.split&.last || "Name"
  end
  private_class_method :omniauth_lastname

  def google_connected?
    provider == "google_oauth2"
  end

  def full_name
    "#{firstname} #{lastname}".strip
  end

  def admin?
    has_role?(:admin)
  end

  def member_workspaces
    return Workspace.for_select if admin?

    Workspace.where(id: workspace_id)
  end

  def is_editor?
    admin? || has_role?(:editor)
  end

  def create_default_plan
    plan_type = PlanType.find_by(code: "basic")
    return unless plan_type

    Plan.create!(
      plan_type: plan_type,
      user: self,
      workspace: workspace,
      valid_from: Date.current,
      valid_to: Date.current + 365.days
    )
  end

  private

  def ensure_owned_workspace
    return if workspace_id.present?

    created = Workspace.create!(user: self)
    self.workspace_id = created.id
    association(:workspace).reset
    self.workspace = created
  end

  def password_or_oauth
    return if password_digest.present? || (provider.present? && uid.present?)
    errors.add(:base, "Password can't be blank") if password.blank?
  end

  def password_confirmation_match
    return if password == password_confirmation
    errors.add(:password_confirmation, "doesn't match Password")
  end
end
