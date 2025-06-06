class RsvpsController < ApplicationController
  def index
    redirect_to new_rsvp_path
  end

  def new
    # redirect to home page for /rsvp or /rsvp/new
    if params[:slug].nil?
      redirect_to root_url
      return
    end

    @rsvp = RSVP.new(params[:rsvp])

    begin
      @show = Show.friendly.find(params[:slug])

      # don't allow RSVPs for past shows
      if @show.occurred?
        redirect_to root_url
        return
      end
    rescue ActiveRecord::RecordNotFound
      # redirect to home page for nonexistent show slug
      redirect_to root_url
      return
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
          @rsvp.phone_number = person.phone_number
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

    @rsvp.referrer = request.referer

    if Settings.rsvp.response.include?(params[:response])
      @rsvp.response = params[:response]
      @rsvp.show_id = @show.id if @show.id
    end

    return unless @rsvp.response == "no" && @rsvp.save

    # show a "no" RSVP
    render "thanks"
  end

  def create
    # look for an existing reservation
    @rsvp = RSVP.where(show_id: params[:rsvp][:show_id], email: params[:rsvp][:email]).first if params[:rsvp] && params[:rsvp][:email] && params[:rsvp][:show_id]

    saved = false

    # create a new reservation
    if @rsvp.nil?
      @rsvp = RSVP.new(rsvp_params)
      saved = @rsvp.save

    # update an existing reservation
    else
      saved = @rsvp.update(rsvp_params)
    end

    @show = Show.find(params[:rsvp][:show_id]) if params[:rsvp] && params[:rsvp][:show_id].to_i.positive?

    # don't show "thanks" message on error
    return unless saved

    render "thanks"
  end

  def rsvp_params
    params.expect(rsvp: %i[first_name last_name email phone_number show_id postcode response seats_reserved referrer])
  end
end
