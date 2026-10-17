# Saves exported invite history (see Export) as InviteMessage revisions.
# Each entry goes to the first show starting after its commit, or to the show
# its "show" slug names; "skip: true" leaves it out. #rows says what each
# entry will do, so a dry run can be checked and corrected before #save!.
#
# Entries already imported (by source_commit) are skipped, so it can be rerun.
# Shows with revisions written in backstage are left alone, since imported
# revisions would be numbered after them.
module InviteHistory
  class Import
    SHOW_TOKEN = /\{\{show\.([\w.]+)\}\}/

    # An entry, its show, its intro and about with the show's fields filled
    # in, and why it's skipped (nil if it will be saved).
    Row = Data.define(:entry, :show, :intro, :about, :skip_reason) do
      def save? = skip_reason.nil?
    end

    def initialize(entries, admin:)
      @entries = entries
      @admin = admin
    end

    def rows
      @rows ||= begin
        # Each show's latest revision text, to skip entries that repeat it.
        previous_text = Hash.new { |texts, show| texts[show] = show.invite_message&.then { [ it.intro, it.about ] } }
        @entries.map do |entry|
          show = show_for(entry)
          intro, about = [ entry["intro"], entry["about"] ].map { fill_in(it.to_s, show) } if show
          reason = skip_reason(entry, show, intro, about, show && previous_text[show])
          previous_text[show] = [ intro, about ] unless reason
          Row.new(entry:, show:, intro:, about:, skip_reason: reason)
        end
      end
    end

    def save!
      InviteMessage.transaction do
        rows.select(&:save?).each do |row|
          date = Time.iso8601(row.entry["date"])
          row.show.invite_messages.create!(intro: row.intro, about: row.about, admin: @admin, source_commit: row.entry["commit"],
                                           created_at: date, updated_at: date)
        end
      end
    end

    private

      def show_for(entry)
        return Show.find_by(slug: entry["show"]) if entry["show"]

        Show.where(start: Time.iso8601(entry["date"])..).order(:start).first
      end

      def skip_reason(entry, show, intro, about, previous_text)
        return "marked skip" if entry["skip"]
        return entry["show"] ? "no show “#{entry['show']}”" : "no show after #{entry['date']}" unless show
        return "already imported" if InviteMessage.exists?(source_commit: entry["commit"])
        return "#{show.slug} has revisions written in backstage" if show.invite_messages.exists?(source_commit: nil)
        return "same text as the previous revision" if [ intro, about ] == previous_text

        unfilled = "#{intro} #{about}".scan(Converter::TOKEN).uniq
        return "can’t fill in #{unfilled.to_sentence}" if unfilled.any?

        message = InviteMessage.new(show:, intro:, about:)
        message.errors.full_messages.to_sentence unless message.valid?
      end

      def fill_in(markdown, show)
        markdown.gsub(SHOW_TOKEN) do |token|
          field = Converter::SHOW_FIELDS[Regexp.last_match(1)]
          field ? field.call(show).to_s : token
        end
      end
  end
end
