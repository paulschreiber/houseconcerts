require "csv"

# Bulk-adds people to the mailing list from text with one person per line,
# in any of these forms (they can be mixed):
#
#   First Last <email@example.com>
#   First,Last,email@example.com
#   First<tab>Last<tab>email@example.com
#
# Used by the admin import page and the people:import_subscribers rake task.
# Someone who already has a Person record -- including anyone who
# unsubscribed, bounced or moved -- is skipped, never re-added.
class ImportPeople
  # Raised before anything is imported: a file without a .csv, .tsv or .txt
  # extension, too many bytes, data that isn't text, or too many lines.
  class Error < StandardError; end

  # added: the new people. skipped: a Line for each person already on file
  # or listed twice. invalid: a Line for each line that couldn't be imported.
  # Each Line has the reason.
  Result = Data.define(:added, :skipped, :invalid)
  Line = Data.define(:number, :text, :reason)

  # A name, then the email in angle brackets, optionally followed by the
  # comma or semicolon that separates addresses copied from an email header.
  NAME_AND_EMAIL = /\A(.+?)\s*<([^<>\s]+)>\s*[,;]?\z/

  EXTENSIONS = %w[.csv .tsv .txt].freeze

  def self.call(data, **)
    new(data, **).call
  end

  # filename: the file's name, if the data came from a file; it must end in
  # .csv, .tsv or .txt.
  def initialize(data, filename: nil, max_lines: Settings.import.max_lines, max_bytes: Settings.import.max_bytes)
    @data = data.to_s.dup.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
    @filename = filename
    @max_lines = max_lines
    @max_bytes = max_bytes
  end

  def call
    check!
    lines = data.split(/\r\n|\r|\n/)
    raise Error, "#{lines.size} lines is too many; the most is #{max_lines}." if lines.size > max_lines

    result = Result.new(added: [], skipped: [], invalid: [])
    seen = Set.new
    lines.each.with_index(1) { |line, number| import(line.strip, number, result, seen) }
    result
  end

  private

    attr_reader :data, :filename, :max_lines, :max_bytes

    def check!
      raise Error, "#{filename} isn’t a .csv, .tsv or .txt file." if wrong_extension?
      raise Error, "#{source_name} is too big; the most is #{ActiveSupport::NumberHelper.number_to_human_size(max_bytes)}." if data.bytesize > max_bytes
      raise Error, "#{source_name} isn’t a text file." unless text?
    end

    def source_name = filename || "That"

    def wrong_extension?
      filename.present? && EXTENSIONS.exclude?(File.extname(filename).downcase)
    end

    # UTF-8 with no control characters other than tabs and line breaks. For
    # a named file, Marcel (Rails' file type detection) mustn't recognize it
    # as some other kind of file (a PDF, a spreadsheet); octet-stream means it
    # doesn't recognize it at all.
    def text?
      return false unless data.valid_encoding? && !data.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/)
      return true unless filename

      type = Marcel::MimeType.for(StringIO.new(data), name: filename)
      type.start_with?("text/") || type == "application/octet-stream"
    end

    def import(line, number, result, seen)
      return if line.empty?

      first_name, last_name, email = parse(line)
      if email.nil?
        result.invalid << Line.new(number:, text: line, reason: "not in a recognized format")
        return
      end

      email = email.strip.downcase
      if seen.include?(email)
        result.skipped << Line.new(number:, text: line, reason: "listed twice in this file")
        return
      end
      seen << email

      if Person.exists?(email:)
        result.skipped << Line.new(number:, text: line, reason: "already on file")
        return
      end

      person = Person.create(first_name:, last_name:, email:)
      if person.persisted?
        result.added << person
      else
        result.invalid << Line.new(number:, text: line, reason: person.errors.full_messages.to_sentence)
      end
    rescue ActiveRecord::RecordNotUnique
      result.skipped << Line.new(number:, text: line, reason: "already on file")
    end

    # Returns [first, last, email], or nil if the line isn't in one of the
    # three forms.
    def parse(line)
      if (match = line.match(NAME_AND_EMAIL))
        first_name, last_name = split_name(match[1])
        fields = [ first_name, last_name, match[2] ]
      else
        fields = delimited_fields(line)&.map { |field| field.to_s.strip }
      end
      fields if fields&.size == 3 && fields.all?(&:present?)
    end

    def delimited_fields(line)
      if line.include?("\t")
        line.split("\t")
      elsif line.include?(",")
        CSV.parse_line(line)
      end
    rescue CSV::MalformedCSVError
      nil
    end

    # A display name, without any quotes around it: "Last, First", or
    # "First Last" where, as in name_paste_controller.js, everything before
    # the last space is the first name ("Mary Jane Watson" is first="Mary
    # Jane", last="Watson"; "John Q Public" is first="John Q",
    # last="Public").
    def split_name(name)
      name = name.strip.delete_prefix('"').delete_suffix('"').strip
      if name.include?(",")
        last_name, first_name = name.split(",", 2).map(&:strip)
      else
        first_name, _, last_name = name.rpartition(" ")
      end
      [ first_name.strip, last_name.strip ]
    end
end
