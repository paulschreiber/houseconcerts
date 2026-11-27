module Madmin
  class DashboardController < Madmin::ApplicationController
    helper DashboardHelper, DashboardGraphHelper

    def show
      @dashboard = Dashboard.new
      @site_health_failures = SiteHealth.failures
      # Upcoming shows only: a past show's failed sends can't be retried.
      @failed_batch_items = BatchRunItem.failed.eager_load(batch_run: :show).where(shows: { start: Time.zone.now.. })
    end
  end
end
