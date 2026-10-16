require "test_helper"

module InviteHistory
  class ConverterTest < ActiveSupport::TestCase
    BUTTON_STYLE = "style: 'background-color: #408000; color: white;'".freeze

    # The template as it last was before the invite editor, with intro and
    # about filled in.
    def template(intro:, about:, before: "", after: "")
      <<~ERB
        <div>
        #{before}
        <p>Hi <%= @person.first_name %>,</p>

        #{intro}

        <ul class="summary">
        <li><%= @show.name %></li>
        <li><%= @show.start_date %> &middot; <%= @show.start_time %></li>
        </ul>

        <p class="actions"><strong>
        <%= link_to "Yes! I’m in for \#{@show.name}!", @rsvp_url_yes, class: 'button', #{BUTTON_STYLE} %>
        <%= link_to "Sorry, I can’t make it", @rsvp_url_no, class: 'button', #{BUTTON_STYLE} %>
        </strong></p>

        <h2>A bit about <%= @show.name %></h2>
        #{about}

        <p><%= link_to "Spend \#{@show.day_of_week} evening with \#{@show.name}", @rsvp_url_yes %>.</p>

        <p><br/>Paul</p>

        <p>P.S. If you have moved or don’t want to receive house concert invites, <%= link_to "instantly unsubscribe", @unsub_url %>.</p>
        #{after}
        </div>
      ERB
    end

    test "keeps the intro and about, dropping the template's fixed parts" do
      converter = Converter.new(template(intro: "<p>Happy October!</p>\n\n<p>Next up: Jane!</p>", about: "<p>Jane sings.</p>\n<p>Jane plays.</p>"))

      assert_equal "Happy October!\n\nNext up: Jane!", converter.intro
      assert_equal "Jane sings.\n\nJane plays.", converter.about
      assert_empty converter.warnings
    end

    test "converts formatting and links to Markdown" do
      converter = Converter.new(template(
                                  intro: %(<p>A <strong>bold</strong> and <em>new</em> album, <cite>Songs</cite>. <a href="https://example.com/">Listen</a>.</p>),
                                  about: %(<p>Line one<br>\nline two. <%= link_to "Reserve your seats for \#{@show.name}", @rsvp_url_yes %> or <%= link_to "change it", @rsvp_url %>.</p>)
                                ))

      assert_equal "A **bold** and *new* album, *Songs*. [Listen](https://example.com/).", converter.intro
      assert_equal "Line one\nline two. [Reserve your seats for {{show.name}}][rsvp_yes] or [change it][rsvp].", converter.about
    end

    test "escapes text that Markdown would otherwise format" do
      converter = Converter.new(template(intro: "<p>5 * 3 = 15 [sic], my_name</p>", about: "<p># 1 fan</p>"))

      assert_equal "5 \\* 3 = 15 \\[sic\\], my\\_name", converter.intro
      assert_equal "\\# 1 fan", converter.about
    end

    test "drops the Gmail markup after the template and reads the signature from settings" do
      erb = template(intro: "<p>Happy October!</p>", about: "<p>Jane sings.</p>")
            .sub("<p><br/>Paul</p>", "<p><br/><%= Settings.invites_from_first_name %></p>")
            .sub("</div>\n", "</div>\n<%= ld_json_tag(ld_json_gmail_rsvp_action(@rsvp_url)) %>\n")
      converter = Converter.new(erb)

      assert_equal "Happy October!", converter.intro
      assert_equal "Jane sings.", converter.about
      assert_empty converter.warnings
    end

    test "turns HTML entities into plain text" do
      converter = Converter.new(template(intro: "<p>R&amp;B &lt;3</p>", about: "<p>Simon &amp; Garfunkel</p>"))

      assert_equal "R&B <3", converter.intro
      assert_equal "Simon & Garfunkel", converter.about
    end

    test "escapes lines that Markdown would read as a heading or list, after a line break too" do
      converter = Converter.new(template(intro: "<p>2. Second point<br># Thanks<br>- Paul</p>", about: "<p>Bio.</p>"))

      assert_equal "2\\. Second point\n\\# Thanks\n\\- Paul", converter.intro
      assert_equal "<p>2. Second point<br>\n# Thanks<br>\n- Paul</p>\n", InviteMessage.new(intro: converter.intro).intro_html({})
    end

    test "drops an unsubscribe link outside the footer to its text" do
      converter = Converter.new(template(intro: %(<p>Or <%= link_to "unsubscribe", @unsub_url %>.</p>), about: "<p>Bio.</p>"))

      assert_equal "Or unsubscribe.", converter.intro
      assert_equal [ "Dropped a link to placeholder:unsubscribe" ], converter.warnings
    end

    test "leaves a link whose text is a variable, and a show field it doesn't know, with warnings" do
      converter = Converter.new(template(intro: "<p><%= link_to @label, @rsvp_url_yes %> for <%= @show.price %></p>", about: "<p>Bio.</p>"))

      assert_equal "<%= link\\_to @label, @rsvp\\_url\\_yes %> for <%= @show.price %>", converter.intro
      assert_equal [ "Left ERB it couldn’t convert: <%= link_to @label, @rsvp_url_yes %>", "Left ERB it couldn’t convert: <%= @show.price %>" ],
                   converter.warnings
    end

    test "gathers loose inline content into a paragraph" do
      converter = Converter.new(template(intro: "<p>Hello.</p>", about: %(<p>Bio.</p>\n\n<%= link_to "Reserve your seats", @rsvp_url_yes %>.)))

      assert_equal "Bio.\n\n[Reserve your seats][rsvp_yes].", converter.about
    end

    test "keeps a closing line that isn't the template's own" do
      erb = template(intro: "<p>Hello.</p>", about: "<p>Bio.</p>").sub("Spend \#{@show.day_of_week} evening with \#{@show.name}", "Say yes to Sunday afternoon")

      assert_equal "Bio.\n\n[Say yes to Sunday afternoon][rsvp_yes].", Converter.new(erb).about
    end

    test "moves text from above the greeting and below the signature, with warnings" do
      converter = Converter.new(template(intro: "<p>Hello.</p>", about: "<p>Bio.</p>",
                                         before: "<p><em>This weekend!</em></p>", after: "<p>P.P.S. A fun fact.</p>"))

      assert_equal "*This weekend!*\n\nHello.", converter.intro
      assert_equal "Bio.\n\nP.P.S. A fun fact.", converter.about
      assert_equal [ "Moved text from above the greeting into the intro", "Moved text from below the signature into the about" ], converter.warnings
    end

    test "reads the oldest template, with its plain RSVP link and styled heading" do
      erb = <<~ERB
        <p>Hi <%= @person.first_name %>,</p>

        <p>It’s summer.</p>

        <p style="margin-bottom: 0">Short attention span version</p>
        <ul style="padding: 0.5em 1em;">
        <li><%= @show.name %></li>
        </ul>

        <p>Please let me know whether or not you can come:
        <br><%= link_to @rsvp_url, @rsvp_url %></p>

        <p style="border-bottom: 1px dashed black;">A bit about <%= @show.name %></p>

        <p>Carlos plays.</p>

        <p><br/>Paul</p>

        <img src="http://example.com/t.php?__TRACK__" height="1" width="1">
      ERB

      converter = Converter.new(erb)

      assert_equal "It’s summer.", converter.intro
      assert_equal "Carlos plays.", converter.about
      assert_empty converter.warnings
    end

    test "warns about markup it can only keep the text of" do
      converter = Converter.new(template(intro: "<p>A good idea<sup>1</sup>.</p>", about: "<ul><li>One</li><li>Two</li></ul>"))

      assert_equal "A good idea1.", converter.intro
      assert_equal "One\n\nTwo", converter.about
      assert_equal [ "Kept only the text of a <sup>", "Turned a list into separate paragraphs" ], converter.warnings
    end

    test "turns strikethrough into ~~" do
      converter = Converter.new(template(intro: "<p>Canadian <s>political analyst</s> singer-songwriter</p>", about: "<p><del>Old</del> <strike>older</strike></p>"))

      assert_equal "Canadian ~~political analyst~~ singer-songwriter", converter.intro
      assert_equal "~~Old~~ ~~older~~", converter.about
      assert_empty converter.warnings
    end

    test "fixes mistyped cite tags" do
      converter = Converter.new(template(intro: "<p><cite.>Billboard</cite.> and <ite>Performing Songwriter</cite></p>", about: "<p>Bio.</p>"))

      assert_equal "*Billboard* and *Performing Songwriter*", converter.intro
      assert_empty converter.warnings
    end

    test "drops an unsafe link to its text" do
      converter = Converter.new(template(intro: %(<p><a href="javascript:alert(1)">Click</a></p>), about: "<p>Bio.</p>"))

      assert_equal "Click", converter.intro
      assert_equal [ "Dropped a link to javascript:alert(1)" ], converter.warnings
    end

    test "puts everything in the intro when it can't find the template's landmarks" do
      converter = Converter.new("<p>Just a note.</p>")

      assert_equal "Just a note.", converter.intro
      assert_equal "", converter.about
      assert_equal [ "Couldn’t find the template’s greeting, show details, heading and signature, so all of it is in the intro" ], converter.warnings
    end

    test "leaves ERB it doesn't know, with a warning" do
      converter = Converter.new(template(intro: "<p>See <%= @venue.url %>.</p>", about: "<p>Bio.</p>"))

      assert_equal "See <%= @venue.url %>.", converter.intro
      assert_equal [ "Left ERB it couldn’t convert: <%= @venue.url %>" ], converter.warnings
    end
  end
end
