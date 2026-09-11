# frozen_string_literal: true

# Tasks in the `railsapp` namespace. Loaded via lib/tasks/railsapp.rake
# because Rails autoloads only `lib/tasks/**/*.rake`.

namespace :railsapp do
  namespace :accounts do
    desc "Create an account for every user that does not have one"
    task check: :environment do
      created = 0

      User.where(account_id: nil).find_each do |user|
        account = Account.create!(user: user)
        user.update_column(:account_id, account.id) if user.account_id.blank?
        created += 1
      end

      puts "Created #{created} account(s)."
    end
  end
end
