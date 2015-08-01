class ShowsController < ApplicationController
  def index
    @shows = Show.occurring
  end

  def shows
    @shows = Show.past.occurred
  end
end
