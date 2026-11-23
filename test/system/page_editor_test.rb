require "application_system_test_case"

# The page editor's preview updates as you type (live_preview_controller.js),
# and its form saves in the browser, so it runs in a real browser.
class PageEditorTest < ApplicationSystemTestCase
  setup do
    sign_in_as_admin
    visit edit_madmin_page_path("about")
  end

  test "the preview shows the saved text, then unsaved edits as they're typed" do
    within_frame("page-preview") { assert_selector "h3", text: "Where is the concert?" }

    fill_in "Text", with: "# A new heading\n\n### Another question?\n\nAn *answer*."

    within_frame("page-preview") do
      assert_selector "h1", text: "A new heading"
      assert_selector "h3", text: "Another question?"
      assert_selector "em", text: "answer"
    end
    assert_includes pages(:about).reload.body, "Where is the concert?"
  end

  test "saving updates the page visitors see and its tab title" do
    fill_in "Title", with: "About these shows"
    fill_in "Text", with: "# Our concerts\n\nCome along."
    click_button "Update Page"

    assert_text "Saved “About these shows”."

    visit about_path
    assert_selector "h1", text: "Our concerts"
    assert_text "Come along."
    assert_equal "About these shows » #{Settings.site_name}", title
  end
end
