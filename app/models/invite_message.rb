class InviteMessage < ApplicationRecord
  # The invite's two editable sections allow only paragraphs, bold, italics
  # and links. Anything else Markdown produces is reduced to its text.
  ALLOWED_TAGS = %w[p br strong em a].freeze

  # Per-person links, written as [text][rsvp_yes]. The mailer supplies each
  # recipient's URLs (see #intro_html).
  PLACEHOLDERS = %w[rsvp_yes rsvp_no rsvp].freeze

  # [text][name], or [name][] which uses the text as the name.
  REFERENCE_LINK = /\[([^\]]+)\]\[([^\]]*)\]/

  belongs_to :show
  belongs_to :admin, optional: true
  # Only batches that never sent anything can be left when it's deleted.
  has_many :batch_runs, dependent: :nullify

  before_validation :assign_revision, on: :create
  before_update :prevent_changes_once_sent
  # Ahead of has_many's dependent handling, which would otherwise detach the
  # batches that lock it first.
  before_destroy :prevent_changes_once_sent, prepend: true

  # Well past any invite so far, and inside MySQL's TEXT limit (64KB) even
  # at four bytes a character.
  MAXIMUM_LENGTH = 10_000

  validates :intro, :about, presence: true, length: { maximum: MAXIMUM_LENGTH }
  validate :placeholders_are_known

  def self.sanitizer
    @sanitizer ||= Rails::HTML5::SafeListSanitizer.new
  end

  # A batch that has used this revision, unless it ended without sending
  # anything (cancelled first, or no one to send to). A sent revision can't be
  # edited or deleted, so it stays a record of what went out.
  def locked?
    batch_runs.where.not(status: :completed).or(batch_runs.delivered).exists?
  end

  def to_param
    revision&.to_s
  end

  def locked_notice
    "Revision #{revision} has been sent, so it can’t be changed. Start a new revision instead."
  end

  # Only a show's highest revision is sent.
  def current?
    self == show.invite_message
  end

  def intro_html(links)
    render(intro, links)
  end

  def about_html(links)
    render(about, links)
  end

  private

    def assign_revision
      self.revision ||= show.invite_messages.maximum(:revision).to_i + 1 if show
    end

    def prevent_changes_once_sent
      return unless locked?

      errors.add(:base, locked_notice)
      throw :abort
    end

    def placeholders_are_known
      { intro:, about: }.each do |attribute, markdown|
        markdown.to_s.scan(REFERENCE_LINK) do |text, name|
          name = text if name.empty?
          next if PLACEHOLDERS.include?(name.downcase)

          errors.add(attribute, "links to “#{name}”, which isn’t a link name. Use #{PLACEHOLDERS.to_sentence(last_word_connector: ' or ', two_words_connector: ' or ')}.")
        end
      end
    end

    # links maps each placeholder to its URL. They're added as Markdown link
    # definitions, so [text][rsvp_yes] links to links[:rsvp_yes].
    def render(markdown, links)
      definitions = links.map { |name, url| "[#{name}]: #{url}" }.join("\n")
      # A parser per render: Redcarpet keeps each render's link definitions on
      # the parser, so a shared one could mix up two recipients' links when
      # jobs render invites at the same time.
      html = MarkdownRenderer.parser(no_intra_emphasis: true).render("#{markdown}\n\n#{definitions}")
      self.class.sanitizer.sanitize(html, tags: ALLOWED_TAGS, attributes: %w[href]).html_safe # rubocop:disable Rails/OutputSafety
    end
end
