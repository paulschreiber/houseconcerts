require "test_helper"

class PageTest < ActiveSupport::TestCase
  test "is found by its slug" do
    assert_equal "about", pages(:about).to_param
  end

  test "for finds the saved page" do
    assert_equal pages(:about), Page.for("about")
  end

  test "for builds an unsaved page from the neutral text when none is saved" do
    Page.delete_all

    page = Page.for("musicians")

    assert_predicate page, :new_record?
    assert_equal I18n.t("pages.musicians.title"), page.title
    assert_equal I18n.t("pages.musicians.body"), page.body
    assert_predicate page, :valid?
  end

  test "for refuses a slug that isn't one of the site's pages" do
    assert_raises(ActiveRecord::RecordNotFound) { Page.for("contact") }
  end

  test "only the site's pages can exist, once each" do
    assert_not Page.new(slug: "contact", title: "Contact", body: "Hello").valid?
    assert_not Page.new(slug: "about", title: "Another", body: "Hello").valid?
  end

  test "needs a title and a body" do
    page = pages(:about)
    page.assign_attributes(title: " ", body: "")

    assert_not page.valid?
    assert_includes page.errors[:title], "can't be blank"
    assert_includes page.errors[:body], "can't be blank"
  end

  test "limits the body to what the column can hold" do
    page = pages(:about)
    page.body = "a" * (Page::MAXIMUM_LENGTH + 1)

    assert_not page.valid?
    assert_predicate page.errors[:body], :present?
  end

  test "trims the title" do
    assert_equal "About", Page.new(title: "  About ").title
  end

  test "body_html renders headings with ids, paragraphs, lists and links" do
    page = Page.new(body: "## Requirements\n\n### Where?\n\nHere. [Home](/about)\n\n* one\n* two\n\n1. first")

    html = page.body_html

    assert_includes html, %(<h2 id="requirements">Requirements</h2>)
    assert_includes html, %(<h3 id="where">Where?</h3>)
    assert_includes html, %(<a href="/about">Home</a>)
    assert_includes html, "<li>one</li>"
    assert_includes html, "<ol>"
  end

  test "body_html links to the home page" do
    assert_includes Page.new(body: "[home page](/)").body_html, %(<a href="/">home page</a>)
    assert_no_match(/<a /, Page.new(body: "[x](//evil.example/x)").body_html)
  end

  test "body_html links to a heading by its id" do
    assert_includes pages(:musicians).body_html, %(<a href="#requirements">Read the requirements</a>)
    assert_includes pages(:musicians).body_html, %(<h2 id="requirements">)
  end

  test "body_html shows HTML and unsafe links as text" do
    html = Page.new(body: "<script>alert(1)</script> <b>bold</b> [x](javascript:alert(1)) <img src=x onerror=alert(1)>").body_html

    assert_no_match(/<script|<b>|<img|href="javascript/, html)
    assert_includes html, "&lt;script&gt;"
  end

  test "body_html drops tags outside the allowed list" do
    html = Page.new(body: "Text\n\n---\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n> quoted\n\n`code`").body_html

    assert_no_match(/<hr|<table|<blockquote|<code/, html)
  end
end
