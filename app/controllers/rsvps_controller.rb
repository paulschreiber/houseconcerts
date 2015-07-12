class RsvpsController < ApplicationController
  def index
    redirect_to new_rsvp_path
  end

  def new
    @rsvp = RSVP.new(params[:rsvp])
    begin
      @show = Show.friendly.find(params[:slug])
    rescue ActiveRecord::RecordNotFound
      @show = Show.new
      @shows = Show.upcoming.confirmed
    end
  end

  def create
    # look for an existing reservation
    if params[:rsvp] && params[:rsvp][:email] && params[:rsvp][:show_id]
      @rsvp = RSVP.where(show_id: params[:rsvp][:show_id], email: params[:rsvp][:email]).first
    end

    # update an existing reservation
    if @rsvp.nil?
      @rsvp = RSVP.new(rsvp_params)

    # create a new reservation
    else
      @rsvp.update(rsvp_params)
    end

    @show = Show.find(params[:rsvp][:show_id])
    @shows = Show.upcoming.confirmed

    if @rsvp.save
      render 'thanks' and return
    end
  end

  def rsvp_params
    params.require(:rsvp).permit(:first_name, :last_name, :email, :show_id, :postcode, :response, :seats)
  end

end