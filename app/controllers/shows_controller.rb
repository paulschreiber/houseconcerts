class ShowsController < ApplicationController
  def index
    @shows = Show.occurring
  end

  def shows
    @shows = Show.past.occurred
  end

  def ical
    render nothing: true
  end
end
