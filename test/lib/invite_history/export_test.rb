require "test_helper"

module InviteHistory
  class ExportTest < ActiveSupport::TestCase
    def invite(intro)
      <<~ERB
        <p>Hi <%= @person.first_name %>,</p>
        <p>#{intro}</p>
        <ul><li><%= @show.name %></li></ul>
        <h2>A bit about <%= @show.name %></h2>
        <p>Bio.</p>
        <p><br/>Paul</p>
      ERB
    end

    def version(intro, commit: SecureRandom.hex(20))
      Export::Version.new(commit:, date: Time.zone.parse("2025-03-09 12:00"), subject: "fix: update invite", erb: invite(intro))
    end

    def git(dir, *)
      system("git", "-C", dir, "-c", "user.name=Jane Smith", "-c", "user.email=jane.smith@example.com", "-c", "commit.gpgsign=false",
             *, exception: true, out: File::NULL, err: File::NULL)
    end

    def commit_file(dir, path, content, message)
      FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
      File.write(File.join(dir, path), content)
      git(dir, "add", "-A")
      git(dir, "commit", "-m", message)
    end

    test "versions reads each commit's template from git, across its moves, until the invite editor" do
      Dir.mktmpdir do |dir|
        git(dir, "init")
        commit_file(dir, "app/views/invites/invite.html.erb", invite("First"), "first invite")
        git(dir, "mv", "app/views/invites", "app/views/invites_mailer")
        git(dir, "commit", "-m", "rename folder")
        commit_file(dir, "app/views/invites_mailer/invite.html.erb", invite("Second"), "second invite")
        commit_file(dir, "app/views/invites_mailer/invite.html.erb", "<%= @invite_message.intro_html(@links) %>", "invite editor")

        versions = Export.versions(dir)

        assert_equal [ "first invite", "rename folder", "second invite" ], versions.map(&:subject)
        assert_includes versions.last.erb, "Second"
        assert_match(/\A\h{40}\z/, versions.first.commit)
      end
    end

    test "entries converts each version, leaving out ones whose text didn't change" do
      entries = Export.entries([ version("First", commit: "a" * 40), version("First"), version("Second", commit: "b" * 40) ])

      assert_equal [ "a" * 40, "b" * 40 ], entries.pluck("commit")
      assert_equal({ "commit" => "a" * 40, "date" => "2025-03-09T12:00:00-04:00", "subject" => "fix: update invite", "intro" => "First", "about" => "Bio." },
                   entries.first)
    end

    test "entries include the converter's warnings" do
      entries = Export.entries([ version("A <s>struck</s> word") ])

      assert_equal [ "Kept only the text of a <s>" ], entries.first["warnings"]
    end
  end
end
