# [text](url) links are limited to SAFE_LINK: http, https, mailto, tel, and
# relative "/" and "#" links. Redcarpet's safe_links_only list can't be
# changed to add tel, so #link replaces Redcarpet's own version, check, and
# escaping. As with Redcarpet's check, "/" and "#" need a letter or digit
# next, which keeps out "//evil.example". Returning nil leaves an unsafe
# link as escaped plain text. <url> autolinks still use Redcarpet's own
# renderer and safe_links_only check.
class MarkdownRenderer < Redcarpet::Render::HTML
  SAFE_LINK = %r{\A(?:https?://[[:alnum:]]|mailto:|tel:\+?[\d(]|[/#][[:alnum:]])}i

  # A Markdown parser using this renderer, with any Redcarpet extensions.
  def self.parser(**extensions)
    Redcarpet::Markdown.new(new(hard_wrap: true, escape_html: true, safe_links_only: true), **extensions)
  end

  # [text](url "title")
  def link(link, title, content)
    return unless link&.match?(SAFE_LINK)

    title_attribute = %( title="#{ERB::Util.html_escape(title)}") if title.present?
    %(<a href="#{ERB::Util.html_escape(link)}"#{title_attribute}>#{content}</a>)
  end
end
