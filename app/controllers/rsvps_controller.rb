class RsvpsController < ApplicationController
  include HtmlOnly

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

      # only allow RSVPs for confirmed, upcoming shows
      unless @show.accepting_rsvps?
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
          @rsvp.assign_attributes(person.rsvp_prefill_attributes)

        # existing RSVP found
        else
          @rsvp = rsvp
        end

      # See if the uniqid is for an RSVP
      else
        rsvp = RSVP.find_by(uniqid: params[:uniqid])

        if rsvp&.show_id == @show.id
          @rsvp = rsvp

        # An RSVP token under a different show's slug (only possible by
        # editing the URL). Treat it like a person's link -- this show's RSVP
        # for that email, or a new one prefilled from it -- instead of moving
        # that RSVP onto this show.
        elsif rsvp
          @rsvp = RSVP.find_by(email: rsvp.email, show_id: @show.id) ||
                  @rsvp.tap { |new_rsvp| new_rsvp.assign_attributes(rsvp.slice(:first_name, :last_name, :email, :phone_number, :postcode)) }
        end
      end
    end

    @rsvp.referrer = request.referer

    if RSVP.responses.key?(params[:response])
      @rsvp.response = params[:response]
      @rsvp.show_id = @show.id if @show.id
    end

    return unless params[:response] == "no" && @rsvp.save

    # show a "no" RSVP
    redirect_to rsvp_thanks_path(uniqid: @rsvp.uniqid)
  end

  def create
    # look for an existing reservation
    # Read through rsvp_params, not params.dig: malformed params (rsvp sent as
    # a string, or email as an array) are a 400 there, not a crash.
    email   = rsvp_params[:email]
    show_id = rsvp_params[:show_id].to_i

    # only allow RSVPs for confirmed, upcoming shows, as in #new; checked here
    # too because the form can be posted directly
    show = Show.find_by(id: show_id)
    unless show&.accepting_rsvps?
      redirect_to root_url
      return
    end

    @rsvp = RSVP.find_by(show_id: show_id, email: email) if email.present?

    # create a new reservation
    saved = if @rsvp.nil?
      create_rsvp

    # update an existing reservation
    else
      @rsvp.update(rsvp_params)
    end

    if saved
      redirect_to rsvp_thanks_path(uniqid: @rsvp.uniqid)
    else
      @show = show
      render :create, status: :unprocessable_content
    end
  end

  def thanks
    @rsvp = RSVP.find_by(uniqid: params[:uniqid])
    redirect_to root_url if @rsvp.nil? || @rsvp.show.nil? || !@rsvp.show.confirmed? || @rsvp.show.occurred?
  end

  def rsvp_params
    params.expect(rsvp: %i[first_name last_name email phone_number show_id postcode response seats_reserved referrer])
  end

  # Two concurrent submissions for the same show/email can both miss the
  # find_by above and race to create; the DB's unique index rejects the
  # loser, which we recover by updating the row the winner created.
  def create_rsvp
    @rsvp = RSVP.new(rsvp_params)
    @rsvp.save
  rescue ActiveRecord::RecordNotUnique
    winner = RSVP.find_by(show_id: @rsvp.show_id, email: @rsvp.email)

    # The unique index violation should mean the winning row is right there
    # to recover by updating, but fall back to re-rendering the form with
    # the submitted data instead of crashing if it's somehow not found (e.g.
    # a different unique index, or the row was deleted in between).
    if winner
      @rsvp = winner
      @rsvp.update(rsvp_params)
    else
      @rsvp.errors.add(:base, "couldn’t be saved. Please try again.")
      false
    end
  end
end
