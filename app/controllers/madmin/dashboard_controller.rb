module Madmin
  class DashboardController < Madmin::ApplicationController
    def show
      @failed_batch_items = BatchRunItem.failed.includes(batch_run: :show)
    end
  end
end
