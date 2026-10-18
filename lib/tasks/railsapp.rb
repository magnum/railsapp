# frozen_string_literal: true

require "io/console"

# Tasks in the `railsapp` namespace. Loaded via lib/tasks/railsapp.rake
# because Rails autoloads only `lib/tasks/**/*.rake`.

namespace :railsapp do
  desc "Create the first workspace and admin user when they do not exist"
  task init: :environment do
    workspace = Workspace.order(:id).first
    if workspace
      puts "Workspace already exists (##{workspace.id})."
    else
      workspace = Workspace.new(name: "My Workspace")
      workspace.save(validate: false) || abort("Failed to create workspace.")
      puts "Created workspace ##{workspace.id}."
    end

    if User.with_role(:admin).exists?
      puts "Admin user already exists."
      next
    end

    email = RailsappInit.ask("Email")
    firstname = RailsappInit.ask("Firstname")
    lastname = RailsappInit.ask("Lastname")
    password = RailsappInit.ask("Password", secret: true)

    user = User.new(
      email: email.downcase,
      firstname: firstname,
      lastname: lastname,
      password: password,
      password_confirmation: password,
      workspace: workspace
    )
    unless user.save
      abort "Failed to create admin user: #{user.errors.full_messages.to_sentence}"
    end

    user.add_role(:admin)
    workspace.update!(user: user) if workspace.user_id.blank?
    puts "Created admin user #{user.email}."
  end

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

module RailsappInit
  module_function

  def ask(label, secret: false)
    loop do
      print "#{label}: "
      value = read_value(secret)
      return value if value.present?

      puts "#{label} is required."
      abort "No input." if $stdin.eof?
    end
  end

  def read_value(secret)
    value = if secret && $stdin.respond_to?(:tty?) && $stdin.tty?
      $stdin.noecho(&:gets)
    else
      $stdin.gets
    end
    puts if secret && $stdin.respond_to?(:tty?) && $stdin.tty?
    value.to_s.strip
  end
end
