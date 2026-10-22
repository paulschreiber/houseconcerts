require "test_helper"

class InvitesRakeTest < ActiveSupport::TestCase
  setup do
    load_rake_tasks
    %w[export_history import_history].each { |task| Rake::Task["invites:#{task}"].reenable }
    @file = Tempfile.new([ "invite_history", ".yml" ])
  end

  teardown do
    @file.close!
    ENV.delete("COMMIT")
  end

  def entry(**attrs)
    { "commit" => SecureRandom.hex(20), "date" => 6.weeks.ago.iso8601, "subject" => "fix: update invite",
      "intro" => "Next up: {{show.name}}!", "about" => "Bio." }.merge(attrs.stringify_keys)
  end

  def write_entries(*entries)
    File.write(@file.path, entries.to_yaml)
  end

  test "export_history writes the entries to a file and lists their warnings" do
    entries = [ entry(commit: "a" * 40, warnings: [ "Kept only the text of a <s>" ]) ]

    out, = with_stubbed(InviteHistory::Export, :entries, -> { entries }) do
      capture_io { Rake::Task["invites:export_history"].invoke(@file.path) }
    end

    assert_equal entries, YAML.safe_load_file(@file.path)
    assert_includes out, "Wrote 1 invites to #{@file.path}"
    assert_includes out, "aaaaaaa fix: update invite\n  Kept only the text of a <s>"
  end

  test "import_history lists where each invite would go, without saving" do
    write_entries(entry, entry(skip: true))

    out, = assert_no_difference("InviteMessage.count") do
      capture_io { Rake::Task["invites:import_history"].invoke(admins(:one).email, @file.path) }
    end

    assert_includes out, "fix: update invite → #{shows(:past).slug}\n"
    assert_includes out, "fix: update invite → #{shows(:past).slug}: skip (marked skip)"
    assert_includes out, "Dry run: nothing saved."
  end

  test "import_history saves the revisions with COMMIT=1" do
    write_entries(entry)

    ENV["COMMIT"] = "1"
    out, = capture_io { Rake::Task["invites:import_history"].invoke(admins(:one).email, @file.path) }

    assert_includes out, "Saved 1 revisions"
    assert_equal "Next up: #{shows(:past).name}!", shows(:past).invite_message.intro
  end

  test "import_history needs an admin's email" do
    _, err = capture_io do
      assert_raises(SystemExit) { Rake::Task["invites:import_history"].invoke("nobody@example.com", @file.path) }
    end

    assert_includes err, "No admin with the email “nobody@example.com”"
  end
end
