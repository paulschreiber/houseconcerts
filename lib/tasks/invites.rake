# One-time import of the invites written by hand in invite.html.erb, from git
# history into InviteMessage revisions. Export runs where the git history is;
# import runs where the shows are.
namespace :invites do
  desc "Write past invites from git history to a YAML file (default db/invite_history.yml)"
  task :export_history, [ :file ] => :environment do |_, args|
    file = args[:file] || InviteHistory::Export::FILE
    entries = InviteHistory::Export.entries
    File.write(file, entries.to_yaml(line_width: -1))
    puts "Wrote #{entries.size} invites to #{file}"
    entries.select { |entry| entry["warnings"] }.each do |entry|
      puts "#{entry['commit'][0, 7]} #{entry['subject']}", *entry["warnings"].map { |warning| "  #{warning}" }
    end
  end

  desc "Save past invites from a YAML file as revisions by an admin: invites:import_history[admin@example.com,file]. Dry run unless COMMIT=1"
  task :import_history, %i[admin_email file] => :environment do |_, args|
    admin = Admin.find_by(email: args[:admin_email].to_s)
    abort "No admin with the email “#{args[:admin_email]}”" unless admin

    file = args[:file] || InviteHistory::Export::FILE
    import = InviteHistory::Import.new(YAML.safe_load_file(file), admin:)
    import.rows.each do |row|
      outcome = [ row.show&.slug, ("skip (#{row.skip_reason})" unless row.save?) ].compact.join(": ")
      puts "#{row.entry['date'][0, 10]} #{row.entry['commit'][0, 7]} #{row.entry['subject']} → #{outcome}"
    end

    if ENV["COMMIT"] == "1"
      import.save!
      puts "Saved #{import.rows.count(&:save?)} revisions"
    else
      puts "Dry run: nothing saved. To change an invite’s show, add “show: <slug>” (or “skip: true”) to its entry in #{file}. " \
           "Then rerun with COMMIT=1."
    end
  end
end
