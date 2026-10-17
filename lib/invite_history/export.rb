# Every version of the hand-edited invite.html.erb in git history, converted
# to Markdown (see Converter), oldest first. Versions that changed only the
# template, not the invite's text, are left out.
module InviteHistory
  module Export
    PATHS = %w[app/views/invite/invite.html.erb app/views/invites/invite.html.erb app/views/invites_mailer/invite.html.erb].freeze
    FILE = Rails.root.join("db/invite_history.yml")

    # A version of the template: its commit and contents.
    Version = Data.define(:commit, :date, :subject, :erb)

    # From git, in the repository at root. Each commit's path is whichever
    # of PATHS it touched that it still has (not one it deleted or moved).
    def self.versions(root = Rails.root)
      log = git(root, "log", "--reverse", "--name-only", "--format=%x1e%H%x1f%aI%x1f%s", "--", *PATHS)
      log.split("\x1e").compact_blank.filter_map do |record|
        header, *paths = record.lines(chomp: true).compact_blank
        commit, date, subject = header.split("\x1f")
        erb = paths.lazy.filter_map { git(root, "show", "#{commit}:#{it}", allow_failure: true) }.first
        # Written in the invite editor from here on.
        next if erb.nil? || erb.include?("@invite_message")

        Version.new(commit:, date: Time.iso8601(date), subject:, erb:)
      end
    end

    # Hashes for YAML: commit, date, subject, intro, about, and any warnings.
    def self.entries(versions = self.versions)
      previous = nil
      versions.filter_map do |version|
        converter = Converter.new(version.erb)
        text = [ converter.intro, converter.about ]
        next if text == previous

        previous = text
        { "commit" => version.commit, "date" => version.date.iso8601, "subject" => version.subject,
          "intro" => converter.intro, "about" => converter.about, "warnings" => converter.warnings.presence }.compact
      end
    end

    def self.git(root, *args, allow_failure: false)
      output, status = Open3.capture2("git", "-C", root.to_s, *args, err: File::NULL)
      return output if status.success?
      return if allow_failure

      raise "git #{args.join(' ')} failed"
    end
    private_class_method :git
  end
end
