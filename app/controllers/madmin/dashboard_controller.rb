module Madmin
  class DashboardController < Madmin::ApplicationController
    helper DashboardHelper

    def show
      @dashboard = Dashboard.new
      # Only shows that haven't happened yet: a past show's failed sends can't
      # be retried (see Madmin::ShowsController#retry_failed_batch_run), so
      # listing them here would just pile up forever.
      @failed_batch_items = BatchRunItem.failed.eager_load(batch_run: :show).where(shows: { start: Time.zone.now.. })
    end
  end
end
