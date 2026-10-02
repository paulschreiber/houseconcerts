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
    prefill_from_link(params[:uniqid]) if params[:uniqid]

    @rsvp.referrer = request.referer

    if RSVP.responses.key?(params[:response])
      @rsvp.response = params[:response]
      @rsvp.show_id = @show.id if @show.id
    end

    return unless params[:response] == "no" && save_no_from_link

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

    if @rsvp.nil? && create_rsvp
      redirect_to rsvp_thanks_path(uniqid: @rsvp.uniqid)
    elsif @rsvp.persisted?
      # an existing RSVP, or one a concurrent request created first
      update_existing_rsvp(show)
    else
      @show = show
      render :create, status: :unprocessable_content
    end
  end

  # Where an update without the RSVP's token lands (see update_existing_rsvp):
  # a page with no token in its URL and none of the guest's details.
  def updated
    @show = Show.find_by(id: flash[:rsvp_updated_show_id])
    @email = flash[:rsvp_updated_email]
    @result = flash[:rsvp_update_result]
    redirect_to root_url if @show.nil? || @email.blank?
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
  # loser. Then @rsvp is the row the winner created, for create to update
  # like any other existing RSVP.
  def create_rsvp
    @rsvp = RSVP.new(rsvp_params)
    @rsvp.save
  rescue ActiveRecord::RecordNotUnique
    winner = RSVP.find_by(show_id: @rsvp.show_id, email: @rsvp.email)

    # The unique index violation should mean the winning row is right there,
    # but fall back to re-rendering the form with the submitted data instead
    # of crashing if it's somehow not found (e.g. a different unique index,
    # or the row was deleted in between).
    if winner
      @rsvp = winner
    else
      @rsvp.errors.add(:base, "couldn’t be saved. Please try again.")
    end
    false
  end

  private

    # A "no" from a link. Real links carry a token, which loads the guest's
    # existing RSVP. A hand-built one (?response=no&rsvp[email]=...) for an
    # email that already has an RSVP for this show would hit the unique
    # index; it isn't saved, the existing RSVP isn't touched, and the form
    # shows instead.
    def save_no_from_link
      @rsvp.save
    rescue ActiveRecord::RecordNotUnique
      false
    end

    # A link's token is a person's (from an invite) or an RSVP's (from a
    # confirmation email). Either way, use this show's RSVP for that email if
    # there is one, or prefill a new one from their details. So an RSVP token
    # under a different show's slug (only possible by editing the URL) never
    # moves that RSVP onto this show.
    def prefill_from_link(uniqid)
      source = Person.find_by(uniqid: uniqid) || RSVP.find_by(uniqid: uniqid)
      return if source.nil?

      existing = RSVP.find_by(email: source.email, show_id: @show.id)

      if existing
        @rsvp = existing
        @verified_link = true
      else
        @rsvp.assign_attributes(source.slice(:first_name, :last_name, :email, :phone_number, :postcode))
      end
    end

    # Anyone who knows a guest's email can update their RSVP from the form.
    # Only a submission carrying the RSVP's token (the form includes it when
    # opened from the guest's own link) gets the full update and the RSVP's
    # private thanks page. Any other submission only changes the response
    # and seats, lands on a page without the token or the guest's details,
    # and (if it changed anything) emails the guest, so a stranger can't read
    # or rewrite their details, and a change they didn't make doesn't go
    # unnoticed. It can't cancel or reduce a "yes" RSVP at all, whether it's
    # confirmed, unconfirmed or waitlisted: on a sold-out show that couldn't
    # be undone, so the guest is emailed their link to make that change
    # themselves.
    def update_existing_rsvp(show)
      @show = show

      if rsvp_token_matches?
        @verified_link = true
        return redirect_to rsvp_thanks_path(uniqid: @rsvp.uniqid) if @rsvp.update(rsvp_params)
      elsif reduces_yes_rsvp?
        InvitesMailer.rsvp_change_requested(@rsvp, @rsvp.seats_reserved).deliver_later if change_request_email_allowed?
        redirect_to rsvp_updated_path, flash: { rsvp_updated_show_id: show.id, rsvp_updated_email: @rsvp.email, rsvp_update_result: "link_sent" }
        return
      else
        previous_response = @rsvp.response
        previous_seats = @rsvp.seats_reserved

        if @rsvp.update(rsvp_params.slice(:response, :seats_reserved))
          changed = @rsvp.saved_changes.keys.intersect?(%w[response seats_reserved])
          if changed
            InvitesMailer.rsvp_updated(@rsvp, { response: previous_response, seats: previous_seats },
                                       { response: @rsvp.response, seats: @rsvp.seats_reserved }).deliver_later
          end
          redirect_to rsvp_updated_path, flash: { rsvp_updated_show_id: show.id, rsvp_updated_email: @rsvp.email,
                                                  rsvp_update_result: changed ? "changed" : "unchanged" }
          return
        end

        # Re-render with what was submitted, not the stored RSVP's details.
        # @updating_existing keeps the form showing on a sold-out show, as it
        # would for the stored RSVP.
        errors = @rsvp.errors
        @rsvp = RSVP.new(rsvp_params)
        @rsvp.errors.merge!(errors)
        @updating_existing = true
      end

      render :create, status: :unprocessable_content
    end

    # A real "no", or a valid smaller seat count. Anything else (blank or
    # invalid seats, a missing response) goes on to fail validation instead.
    def reduces_yes_rsvp?
      return false unless @rsvp.yes?
      return true if rsvp_params[:response] == "no"

      seats = Integer(rsvp_params[:seats_reserved].to_s, exception: false)
      rsvp_params[:response] == "yes" && seats.present? && seats < @rsvp.seats_reserved
    end

    # At most one of these emails per RSVP per hour: each says the same thing,
    # so repeating the request can't flood the guest's inbox.
    def change_request_email_allowed?
      Rails.cache.write("rsvp/change_requested/#{@rsvp.id}", true, expires_in: 1.hour, unless_exist: true)
    end

    def rsvp_token_matches?
      params[:uniqid].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(params[:uniqid], @rsvp.uniqid)
    end
end
