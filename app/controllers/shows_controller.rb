class ShowsController < ApplicationController
  def index
    @shows = Show.upcoming.confirmed
  end

  def shows
    @shows = Show.past.occurred
  end
end
