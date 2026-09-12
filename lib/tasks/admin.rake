namespace :admin do
  desc "Create a development admin user (admin@example.com) with a random password"
  task create_dev_user: :environment do
    abort "This task only runs in the development environment." unless Rails.env.development?

    password = SecureRandom.alphanumeric(16)

    admin = Admin.find_or_initialize_by(email: "admin@example.com")
    admin.password = password
    admin.password_confirmation = password
    admin.save!

    puts "Admin: #{admin.email}"
    puts "Password: #{password}"
  end
end
