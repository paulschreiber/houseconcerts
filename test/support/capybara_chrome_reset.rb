unless Capybara::VERSION == "3.40.0"
  raise "Check whether Capybara #{Capybara::VERSION} resets Chrome 158 itself " \
        "(https://github.com/teamcapybara/capybara/issues/2865). If it does, delete #{__FILE__} " \
        "and the line that requires it; if not, update the version check."
end

# Chrome 158 rejects the "*" origin that Capybara 3.40.0 passes to
# Storage.clearDataForOrigin at the end of ChromeDriver#reset!, which fails
# every system test in teardown. When that happens, this clears all cookies and
# the test server's local storage.
module CapybaraChromeReset
  def reset!
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError => e
    raise unless e.message.include?("* is not a valid URL")

    execute_cdp("Network.clearBrowserCookies")
    execute_cdp("Storage.clearDataForOrigin", origin: Capybara.current_session.server_url, storageTypes: "local_storage") if clear_all_storage?
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraChromeReset)
