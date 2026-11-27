module Madmin
  # Every check of the site’s health (see SiteHealth), passed or not.
  class SiteHealthController < Madmin::ApplicationController
    def index
      @results = SiteHealth.results
    end
  end
end
