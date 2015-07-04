class ShowsController < ApplicationController
  def index
    @shows = Show.upcoming.confirmed
  end
end
