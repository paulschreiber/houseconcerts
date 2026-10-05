module Madmin
  class DashboardController < Madmin::ApplicationController
    helper DashboardHelper

    def show
      @dashboard = Dashboard.new
    end
  end
end
