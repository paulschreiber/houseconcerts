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

    @rsvp = params[:rsvp].present? ? RSVP.new(rsvp_params) : RSVP.new

    begin
      @show = Show.friendly.find(params.expect(:slug))

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
      person = Person.find_by(uniqid: params[:uniqid])

      if person
        # determine if an RSVP exists for this email/show combo
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
        rsvp = RSVP.find_by(uniqid: params[:uniqid])
        @rsvp = rsvp if rsvp
      end
    end

    @rsvp.referrer = request.referer

    if RSVP.responses.key?(params[:response])
      @rsvp.response = params[:response]
      @rsvp.show_id = @show.id if @show.id
    end

    return unless @rsvp.response == "no" && @rsvp.save

    # show a "no" RSVP
    redirect_to rsvp_thanks_path(uniqid: @rsvp.uniqid)
  end

  def create
    # look for an existing reservation
    email   = params.dig(:rsvp, :email)
    show_id = params.dig(:rsvp, :show_id).to_i

    @rsvp = RSVP.find_by(show_id: show_id, email: email) if email.present? && show_id.positive?

    saved = false

    # create a new reservation
    if @rsvp.nil?
      @rsvp = RSVP.new(rsvp_params)
      saved = @rsvp.save

    # update an existing reservation
    else
      saved = @rsvp.update(rsvp_params)
    end

    if saved
      redirect_to rsvp_thanks_path(uniqid: @rsvp.uniqid)
    else
      @show = Show.find(show_id) if show_id.positive?
      render :create, status: :unprocessable_content
    end
  end

  def thanks
    @rsvp = RSVP.find_by(uniqid: params[:uniqid])
    redirect_to root_url if @rsvp.nil?
  end

  def rsvp_params
    params.expect(rsvp: %i[first_name last_name email phone_number show_id postcode response seats_reserved referrer])
  end
end
