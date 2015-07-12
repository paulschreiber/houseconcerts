class RSVPController < ApplicationController
  def new
    @rsvp = RSVP.new(params[:rsvp])
    begin
      @show = Show.friendly.find(params[:slug])
    rescue ActiveRecord::RecordNotFound
      @show = Show.new
      @shows = Show.upcoming.confirmed
    end
  end
end
