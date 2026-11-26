require "application_system_test_case"

class BrowserResetTest < ApplicationSystemTestCase
  test "resetting the browser clears cookies and local storage" do
    visit root_path
    execute_script("document.cookie = 'example=1'; localStorage.setItem('example', '1');")

    Capybara.reset_sessions!
    visit root_path

    assert_not_includes evaluate_script("document.cookie"), "example="
    assert_nil evaluate_script("localStorage.getItem('example')")
  end
end
