module Madmin
  class DashboardController < Madmin::ApplicationController
    helper DashboardHelper

    def show
      @dashboard = Dashboard.new
      # Upcoming shows only: a past show's failed sends can't be retried.
      @failed_batch_items = BatchRunItem.failed.eager_load(batch_run: :show).where(shows: { start: Time.zone.now.. })
    end
  end
end
