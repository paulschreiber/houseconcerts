# A page of text the site links to (About, Musician Info), written in Markdown
# and edited in backstage. The page's heading is the Markdown's own `# Heading`;
# the title is the browser tab's. The pages are fixed: each one's slug picks the
# route that shows it, so admins change a page's text, not which pages exist.
class Page < ApplicationRecord
  SLUGS = %w[about musicians].freeze

  # Paragraphs, headings, lists, bold, italics, strikethrough and links.
  # Anything else Markdown produces is reduced to its text.
  ALLOWED_TAGS = %w[p br strong em del a h1 h2 h3 ul ol li].freeze

  # Well past either page, and inside MySQL's TEXT limit (64KB) even at four
  # bytes a character.
  MAXIMUM_LENGTH = 15_000

  normalizes :title, with: ->(title) { title.strip }

  validates :slug, inclusion: { in: SLUGS }, uniqueness: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :body, presence: true, length: { maximum: MAXIMUM_LENGTH }

  # The saved page with this slug, or an unsaved one with neutral text from
  # the locale file, so a new site has pages to show and edit.
  def self.for(slug)
    raise ActiveRecord::RecordNotFound, "No page “#{slug}”" unless SLUGS.include?(slug)

    find_by(slug:) || new(slug:, title: I18n.t("pages.#{slug}.title"), body: I18n.t("pages.#{slug}.body"))
  end

  def to_param
    slug
  end

  # The body as HTML. Headings get ids from their text, so a link such as
  # [requirements](#requirements) can point at "## Requirements".
  def body_html
    html = MarkdownRenderer.parser(with_toc_data: true, no_intra_emphasis: true, strikethrough: true).render(body.to_s)
    ActionView::Base.safe_list_sanitizer.sanitize(html, tags: ALLOWED_TAGS, attributes: %w[href id title]).html_safe # rubocop:disable Rails/OutputSafety
  end
end
