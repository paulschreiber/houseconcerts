# Turns one version of the old hand-edited invite.html.erb into the two
# Markdown sections an InviteMessage holds. The template's fixed parts (the
# greeting, show details, RSVP buttons, "A bit about" heading and footer) are
# dropped. Anything that doesn't fit the Markdown an invite allows is noted in
# #warnings, for checking by hand.
#
# ERB is resolved before parsing: links to the RSVP URLs become placeholder
# links ([text][rsvp_yes]) and the SHOW_FIELDS become {{show.name}}-style
# tokens, which InviteHistory::Import fills in once it knows the show.
module InviteHistory
  class Converter
    PLACEHOLDER = "placeholder:".freeze
    # The old template's URL variables, as InviteMessage::PLACEHOLDERS names.
    # "unsubscribe" is only for finding the footer's link, which is dropped
    # (see #link).
    URL_PLACEHOLDERS = {
      "@rsvp_url" => "rsvp", "@rsvp_url_yes" => "rsvp_yes", "@rsvp_url_no" => "rsvp_no",
      "@links[:rsvp]" => "rsvp", "@links[:rsvp_yes]" => "rsvp_yes", "@links[:rsvp_no]" => "rsvp_no",
      "@unsub_url" => "unsubscribe"
    }.freeze

    # The show fields an invite can use, and how Import fills each one in.
    SHOW_FIELDS = {
      "name" => :name.to_proc, "day_of_week" => :day_of_week.to_proc, "start_date" => :start_date.to_proc,
      "start_date_short" => :start_date_short.to_proc, "start_time" => :start_time.to_proc, "venue.location" => ->(show) { show.venue.location }
    }.freeze
    TOKEN = /\{\{[\w.]+\}\}/

    # Template machinery with no invite text: the Gmail markup, after the
    # closing </div>.
    MARKUP = /<%=\s*ld_json_tag\(.*?%>/m
    # The signature, once it came from settings instead of being written out.
    SIGNATURE = /<%=\s*Settings\.invites_from_first_name\s*%>/
    # Mistyped tags in old versions, and what they meant.
    TYPOS = { "<cite.>" => "<cite>", "</cite.>" => "</cite>", "<ite>" => "<cite>" }.freeze
    LINK_TO = /<%=\s*link_to\s+(?:"([^"]*)"|(@\w+))\s*,\s*(@\w+(?:\[:\w+\])?)[^%]*%>/
    FIELD = /<%=\s*@?((?:show|person)\.[\w.]+)\s*%>/
    INTERPOLATION = /\#\{@?((?:show|person)\.[\w.]+)\}/

    attr_reader :intro, :about, :warnings

    def initialize(erb)
      @erb = erb
      @warnings = []
      intro, about = split(top_level_nodes)
      @intro = markdown(intro)
      @about = markdown(about)
      @warnings.uniq!
    end

    private

      def html
        erb = @erb.gsub(MARKUP, "").gsub(SIGNATURE, "Paul").gsub(Regexp.union(TYPOS.keys), TYPOS)
        links = erb.gsub(LINK_TO) { placeholder_link(*Regexp.last_match.values_at(0, 1, 2, 3)) }
        tokens(links, FIELD).gsub(/<%.*?%>/m) { unknown_erb(Regexp.last_match(0)) }
      end

      # link_to "text", @rsvp_url_yes as a link to "placeholder:rsvp_yes".
      # Link text from a variable can't be recovered, except for a URL shown
      # as its own text (link_to @rsvp_url, @rsvp_url).
      def placeholder_link(erb, text, text_variable, url)
        name = URL_PLACEHOLDERS[url]
        text ||= "RSVP" if text_variable == url
        return unknown_erb(erb) unless name && text

        %(<a href="#{PLACEHOLDER}#{name}">#{tokens(text, INTERPOLATION)}</a>)
      end

      # The greeting's first name and the SHOW_FIELDS as {{tokens}}; any other
      # field is left as it was, with a warning.
      def tokens(text, pattern)
        text.gsub(pattern) do |erb|
          field = Regexp.last_match(1)
          field == "person.first_name" || SHOW_FIELDS.key?(field.delete_prefix("show.")) ? "{{#{field}}}" : unknown_erb(erb)
        end
      end

      def unknown_erb(erb)
        @warnings << "Left ERB it couldn’t convert: #{erb}"
        erb
      end

      # The template's elements, unwrapped from any container <div>. Loose
      # inline content (a link and a full stop outside any <p>) is gathered
      # into a paragraph of its own.
      def top_level_nodes
        fragment = Nokogiri::HTML5.fragment(html)
        nodes = fragment.children
        while (wrapper = only_div(nodes))
          nodes = wrapper.children
        end

        nodes.chunk_while { |a, b| inline?(a) && inline?(b) }.filter_map do |run|
          next run.first unless inline?(run.first)
          next if run.all? { blank?(it) }

          paragraph = Nokogiri::XML::Node.new("p", fragment.document)
          run.each { paragraph.add_child(it) }
          paragraph
        end
      end

      def only_div(nodes)
        content = nodes.reject { blank?(it) }
        content.first if content.one? && content.first.name == "div"
      end

      def inline?(node)
        node.text? || %w[a strong b em i cite s strike del span br].include?(node.name)
      end

      def blank?(node)
        node.text? && node.text.strip.empty?
      end

      # Splits the nodes around the template's landmarks: intro runs from the
      # greeting to the show details; about from the "A bit about" heading to
      # the signature.
      def split(nodes)
        greeting = nodes.index { text(it).start_with?("Hi {{person.first_name}}") }
        summary = nodes.index { it.name == "ul" }
        heading = nodes.index { text(it).start_with?("A bit about") }
        signature = nodes.index { text(it) == "Paul" }

        unless greeting && summary && heading && signature
          @warnings << "Couldn’t find the template’s greeting, show details, heading and signature, so all of it is in the intro"
          return [ nodes, [] ]
        end

        before = nodes[0...greeting]
        @warnings << "Moved text from above the greeting into the intro" if before.any?
        intro = before + nodes[(greeting + 1)...summary].reject { text(it) == "Short attention span version" }

        between = nodes[(summary + 1)...heading].reject { actions?(it) }
        @warnings << "Moved text from between the show details and the heading into the intro" if between.any?

        about = nodes[(heading + 1)...signature]
        about.pop if standard_closing?(about.last)
        after = nodes[(signature + 1)..].reject { unsubscribe?(it) || it.name == "img" }
        @warnings << "Moved text from below the signature into the about" if after.any?

        [ intro + between, about + after ]
      end

      def text(node)
        node.text.squish
      end

      def links(node)
        node.css("a").pluck("href")
      end

      # The RSVP buttons, or the plain RSVP link they replaced.
      def actions?(node)
        node["class"] == "actions" || links(node).include?("#{PLACEHOLDER}rsvp_no") || text(node).start_with?("Please let me know")
      end

      # The template's own closing line, which the footer now supplies.
      def standard_closing?(node)
        node && text(node).match?(/\ASpend .* evening with .*\.\z/) && links(node).all? { it.start_with?(PLACEHOLDER) }
      end

      def unsubscribe?(node)
        links(node).include?("#{PLACEHOLDER}unsubscribe")
      end

      def markdown(nodes)
        nodes.map { block(it) }.compact_blank.join("\n\n")
      end

      def block(node)
        case node.name
        when "ul", "ol"
          @warnings << "Turned a list into separate paragraphs"
          node.css("li").map { paragraph(it) }.join("\n\n")
        when "h1", "h2", "h3"
          @warnings << "Turned a #{node.name} heading into a bold paragraph"
          "**#{paragraph(node)}**"
        else paragraph(node)
        end
      end

      # Escapes a line that Markdown would read as a heading, quote or list.
      def paragraph(node)
        inline(node).gsub(/ *\n */, "\n").strip.gsub(/^(#|>|[-+*] )/) { "\\#{Regexp.last_match(1)}" }.gsub(/^(\d+)\. /) { "#{Regexp.last_match(1)}\\. " }
      end

      def inline(node)
        return escape(node.text.gsub(/\s+/, " ")) if node.text?

        content = node.children.map { inline(it) }.join
        case node.name
        when "strong", "b" then wrap(content, "**")
        when "em", "i", "cite" then wrap(content, "*")
        when "s", "strike", "del" then wrap(content, "~~")
        when "br" then "\n"
        when "a" then link(node, content)
        when "p", "div", "span", "li", "h1", "h2", "h3" then content
        else
          @warnings << "Kept only the text of a <#{node.name}>"
          content
        end
      end

      # Keeps the markers next to the text, so " *x* " not "* x *".
      def wrap(content, marker)
        return content if content.strip.empty?

        content.sub(/\A(\s*)(.*?)(\s*)\z/m) { "#{Regexp.last_match(1)}#{marker}#{Regexp.last_match(2)}#{marker}#{Regexp.last_match(3)}" }
      end

      def link(node, content)
        href = node["href"].to_s
        name = href.delete_prefix(PLACEHOLDER)
        if InviteMessage::PLACEHOLDERS.include?(name)
          "[#{content}][#{name}]"
        elsif href.match?(MarkdownRenderer::SAFE_LINK)
          "[#{content}](#{href})"
        else
          @warnings << "Dropped a link to #{href}"
          content
        end
      end

      # Backslash-escapes Markdown's inline markers, leaving {{tokens}} alone.
      def escape(text)
        text.split(/(#{TOKEN})/o).each_with_index.map do |part, index|
          index.odd? ? part : part.gsub(/([\\`*_\[\]])/) { "\\#{Regexp.last_match(1)}" }
        end.join
      end
  end
end
