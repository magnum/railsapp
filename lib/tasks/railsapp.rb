# frozen_string_literal: true

# Tasks in the `railsapp` namespace. Loaded via lib/tasks/railsapp.rake
# because Rails autoloads only `lib/tasks/**/*.rake`.

namespace :railsapp do
  namespace :workspaces do
    desc "Create a workspace for every user that does not have one"
    task check: :environment do
      created = 0

      User.where(workspace_id: nil).find_each do |user|
        workspace = Workspace.create!(user: user)
        user.update_column(:workspace_id, workspace.id) if user.workspace_id.blank?
        created += 1
      end

      puts "Created #{created} workspace(s)."
    end
  end
end
