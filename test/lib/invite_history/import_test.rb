require "test_helper"

module InviteHistory
  class ImportTest < ActiveSupport::TestCase
    def entry(date: 6.weeks.ago, **attrs)
      { "commit" => SecureRandom.hex(20), "date" => date.iso8601, "subject" => "fix: update invite",
        "intro" => "Next up: {{show.name}}!", "about" => "Bio. [Join us][rsvp_yes]." }.merge(attrs.stringify_keys)
    end

    def import(*entries)
      Import.new(entries, admin: admins(:one))
    end

    test "goes to the first show starting after the commit" do
      row = import(entry).rows.first

      assert_equal shows(:past), row.show
      assert_predicate row, :save?
    end

    test "goes to the show an entry names" do
      assert_equal shows(:sold_out), import(entry(show: shows(:sold_out).slug)).rows.first.show
    end

    test "skips an entry marked skip, or with no show" do
      later = 1.year.from_now
      reasons = import(entry(skip: true), entry(show: "no-such-show"), entry(date: later)).rows.map(&:skip_reason)

      assert_equal [ "marked skip", "no show “no-such-show”", "no show after #{later.iso8601}" ], reasons
    end

    test "assigns an entry without a show to the next confirmed show, passing over a cancelled one" do
      Show.create!(name: "Cancelled Show", venue: venues(:one), price: 20, start: 1.week.from_now, status: "cancelled")

      assert_equal shows(:upcoming), import(entry(date: 2.weeks.ago)).rows.first.show
    end

    test "leaves alone a show with revisions written in backstage" do
      row = import(entry(date: 2.weeks.ago)).rows.first

      assert_equal shows(:upcoming), row.show
      assert_equal "#{shows(:upcoming).slug} has revisions written in backstage", row.skip_reason
    end

    test "skips an entry with the same text as the show's previous revision" do
      rows = import(entry, entry(subject: "style the template"), entry(about: "New bio.")).rows

      assert_equal [ nil, "same text as the previous revision", nil ], rows.map(&:skip_reason)
    end

    test "skips an entry with a token it can't fill in" do
      assert_equal "can’t fill in {{person.first_name}} and {{show.price}}",
                   import(entry(intro: "Hi {{person.first_name}}", about: "{{show.price}}")).rows.first.skip_reason
    end

    test "skips an entry that wouldn't be a valid revision" do
      assert_equal "About can't be blank", import(entry(about: "")).rows.first.skip_reason
    end

    test "save! saves each entry as the next revision, as it was committed" do
      first = entry(date: 7.weeks.ago)
      second = entry(intro: "Reminder: {{show.day_of_week}}!")

      assert_difference("InviteMessage.count", 2) { import(first, entry(skip: true), second).save! }

      revisions = shows(:past).invite_messages
      assert_equal [ 1, 2 ], revisions.map(&:revision)
      assert_equal "Next up: #{shows(:past).name}!", revisions.first.intro
      assert_equal "Reminder: #{shows(:past).day_of_week}!", revisions.last.intro
      assert_equal first["commit"], revisions.first.source_commit
      assert_equal admins(:one), revisions.first.admin
      assert_equal Time.iso8601(first["date"]), revisions.first.created_at
      assert_equal Time.iso8601(first["date"]), revisions.first.sent_at
      assert_predicate revisions.first, :locked?
    end

    test "save! stores an ampersand as typed, not as &amp;" do
      import(entry(about: "Simon & Garfunkel fans, [join us][rsvp_yes].")).save!

      assert_equal "Simon & Garfunkel fans, [join us][rsvp_yes].", shows(:past).invite_messages.last.about
    end

    test "skips what it has already imported, so it can be rerun" do
      entries = [ entry, entry(about: "New bio.") ]
      import(*entries).save!

      assert_equal [ "already imported", "already imported" ], import(*entries).rows.map(&:skip_reason)
      assert_no_difference("InviteMessage.count") { import(*entries).save! }
    end
  end
end
