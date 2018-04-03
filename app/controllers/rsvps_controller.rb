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
      @shows = Show.occurring
    end

    # pre-fill form (from link)
    if params[:uniqid]
      # See if the uniqid is for a person
      person = Person.where(uniqid: params[:uniqid]).first

      if person
        # determine if an RSVP exists for this emai/show combo
        rsvp = RSVP.where(email: person.email, show_id: @show.id).first

        # no match; create a new object
        if rsvp.nil?
          @rsvp.first_name = person.first_name
          @rsvp.last_name = person.last_name
          @rsvp.email = person.email
          @rsvp.postcode = person.postcode

        # existing RSVP found
        else
          @rsvp = rsvp
        end

      # See if the uniqid is for an RSVP
      else
        rsvp = RSVP.where(uniqid: params[:uniqid]).first
        @rsvp = rsvp if rsvp
      end
    end

    if HC_CONFIG.rsvp.response.include?(params[:response])
      @rsvp.response = params[:response]
      @rsvp.show_id = @show.id if @show.id
    end

    return unless @rsvp.response == 'no' && @rsvp.save

    # show a "no" RSVP
    render 'thanks'
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

    if params[:rsvp] && params[:rsvp][:show_id].to_i > 0
      @show = Show.find(params[:rsvp][:show_id])
    end

    @shows = Show.occurring

    return unless @rsvp.save

    render 'thanks'
  end

  def rsvp_params
    params.require(:rsvp).permit(:first_name, :last_name, :email, :show_id, :postcode, :response, :seats)
  end
end
