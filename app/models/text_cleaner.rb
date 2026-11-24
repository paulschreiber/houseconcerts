# The cleanup text gets before it's stored, for records (ModelCleaners) and for
# the settings forms (SettingsForm): line breaks stored as \n, characters
# nobody can see removed, and leading and trailing whitespace trimmed. Text is
# otherwise kept as typed, markup included: views escape it.
module TextCleaner
  # Control characters other than a line break or tab, and invisible formatting
  # characters: zero-width spaces, right-to-left overrides, the byte order mark.
  HIDDEN = /(?![\n\t])\p{Cc}|\p{Cf}/
  # Every kind of line break (Ruby's R: CRLF, CR, vertical tab, form feed, next
  # line, and the Unicode line and paragraph separators). They become newlines
  # first, so that HIDDEN, which deletes the control characters, doesn't delete
  # the ones that are line breaks.
  LINE_BREAKS = /\R/
  # Whitespace at the ends of the text, including non-breaking and ideographic
  # spaces, which String#strip leaves.
  EDGES = /\A[[:space:]]+|[[:space:]]+\z/

  # one_line: every run of white space around a line break, and every tab,
  # becomes a single space, for text that belongs on one line, such as a name or
  # a meta description. Text that isn't valid UTF-8 or ASCII, such as binary
  # data, is returned as it is.
  def self.clean(text, one_line: false)
    return text unless text.valid_encoding? && [ Encoding::UTF_8, Encoding::US_ASCII ].include?(text.encoding)

    text = text.gsub(LINE_BREAKS, "\n").gsub(HIDDEN, "")
    text = text.gsub(/[[:space:]]*[\n\t][[:space:]]*/, " ") if one_line
    text.gsub(EDGES, "")
  end
end
