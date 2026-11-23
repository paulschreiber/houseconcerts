require "test_helper"

module Madmin
  class PagesControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in admins(:one)
    end

    test "index lists both pages, saved or not" do
      pages(:musicians).destroy

      get madmin_pages_path

      assert_response :success
      assert_select "td a[href=?]", edit_madmin_page_path("about"), text: "About"
      assert_select "td a[href=?]", edit_madmin_page_path("musicians"), text: I18n.t("pages.musicians.title")
      assert_select "td", text: "Not saved yet"
    end

    test "the sidebar links to the pages" do
      get madmin_pages_path

      assert_select "#sidebar a[href=?]", madmin_pages_path, text: "Pages"
    end

    test "edit shows the title and text, with a live preview" do
      get edit_madmin_page_path("about")

      assert_response :success
      assert_select "[data-controller=live-preview] form#page-editor-form[action=?]", madmin_page_path("about")
      assert_select "form input[name='page[title]'][value=About]"
      assert_select "form textarea[name='page[body]']", text: /Frequently asked questions/
      assert_select "label[for=page_title]"
      assert_select "label[for=page_body]"
      assert_select "button[hidden][formaction=?][formtarget=page-preview]", preview_madmin_page_path("about")
      assert_select "iframe[name=page-preview]"
      assert_select ".form-secondary-actions button[type=submit][form=page-editor-form]", text: "Update Page"
      assert_select ".form-secondary-actions a[href=?]", madmin_pages_path, text: "Cancel"
      assert_select "a[href=?]", about_path, text: "View on site"
    end

    test "edit offers a page nobody has saved with its neutral text" do
      ::Page.delete_all

      get edit_madmin_page_path("musicians")

      assert_response :success
      assert_select "form input[name='page[title]'][value=?]", I18n.t("pages.musicians.title")
    end

    test "there is no page but the site's own" do
      get edit_madmin_page_path("contact")

      assert_response :not_found
    end

    test "update saves the title and text" do
      patch madmin_page_path("about"), params: { page: { title: "About us", body: "# About us\n\nHello." } }

      assert_redirected_to edit_madmin_page_path("about")
      assert_equal "Saved “About us”.", flash[:notice]
      page = pages(:about).reload
      assert_equal "About us", page.title
      assert_equal "# About us\n\nHello.", page.body
    end

    test "update saves a page nobody had saved" do
      ::Page.delete_all

      assert_difference -> { ::Page.count }, 1 do
        patch madmin_page_path("musicians"), params: { page: { title: "For musicians", body: "# Musicians" } }
      end

      assert_equal "For musicians", ::Page.find_by!(slug: "musicians").title
    end

    test "update refuses a blank title or text, and keeps the saved page" do
      patch madmin_page_path("about"), params: { page: { title: " ", body: "" } }

      assert_response :unprocessable_content
      assert_select "span.field_with_errors:has(input[name='page[title]']) + p.error", text: "can't be blank"
      assert_select "span.field_with_errors:has(textarea[name='page[body]']) + p.error", text: "can't be blank"
      assert_equal "About", pages(:about).reload.title
      assert_select "h1 strong", text: "Edit About"
    end

    test "update can't change which page it is" do
      patch madmin_page_path("about"), params: { page: { title: "About", body: "Text", slug: "musicians" } }

      assert_equal "about", pages(:about).reload.slug
    end

    test "preview shows the unsaved text in the site’s styles, without saving it" do
      post preview_madmin_page_path("about"), params: { page: { title: "Unsaved title", body: "# Unsaved heading\n\n### A question?\n\nAn *answer*." } }

      assert_response :success
      assert_select "title", text: /\AUnsaved title/
      assert_select "h1", count: 1
      assert_select ".pagetext h1", text: "Unsaved heading"
      assert_select ".pagetext h3", text: "A question?"
      assert_select ".pagetext em", text: "answer"
      assert_equal "About", pages(:about).reload.title
    end

    test "preview is sandboxed and can only be framed by the editor" do
      post preview_madmin_page_path("about"), params: { page: { title: "T", body: "<script>alert(1)</script>" } }

      assert_match(/sandbox/, response.headers["Content-Security-Policy"])
      assert_match(/frame-ancestors 'self'/, response.headers["Content-Security-Policy"])
      assert_no_match(/<script>alert/, response.body)
    end

    test "signed-out visitors are sent to sign in" do
      sign_out :admin

      get edit_madmin_page_path("about")

      assert_response :redirect
      assert_no_match(/Frequently/, response.body)
    end
  end
end
