class MailingListController < ApplicationController
  def unsubscribe
    unless params[:uniqid]
      redirect_to root_url
      return
    end

    @person = Person.find_by(uniqid: params[:uniqid])
    if @person.nil?
      redirect_to root_url
      return
    end

    if @person.removed?
      @already_removed = true
    else
      @already_removed = false
      @person.removed!
    end
  end

  def index
    @person = Person.new
  end

  def create
    # look for an existing subscription
    # Read through person_params, not params.dig: malformed params (person
    # sent as a string, or email as an array) are a 400 there, not a crash.
    email = person_params[:email]
    @person = Person.find_by(email: email) if email.present?

    if @person&.active?
      redirect_to mailing_list_already_subscribed_path(first_name: person_params[:first_name])
      return
    end

    # Someone who unsubscribed (or whose address bounced) has to confirm by
    # email before they're added back, so nobody can re-subscribe them by
    # typing in their address.
    if @person.present?
      MailingListMailer.rejoin(@person).deliver_later if rejoin_email_allowed?(@person)
      redirect_to mailing_list_rejoin_requested_path
      return
    end

    @person = Person.new(person_params)

    if @person.save
      redirect_to mailing_list_thanks_path(uniqid: @person.uniqid)
    else
      render :create, status: :unprocessable_content
    end
  end

  def already_subscribed
    @first_name = params[:first_name]
  end

  def rejoin_requested; end

  # The link in the rejoin email. Shows a confirm button rather than
  # resubscribing on GET, so email link scanners can't resubscribe anyone.
  def rejoin
    @person = Person.find_by(uniqid: params[:uniqid])
    redirect_to root_url if @person.nil?
  end

  def confirm_rejoin
    @person = Person.find_by(uniqid: params[:uniqid])
    if @person.nil?
      redirect_to root_url
      return
    end

    @person.update!(status: :active, removed_at: nil, removal_ip_address: nil) unless @person.active?
    redirect_to mailing_list_thanks_path(uniqid: @person.uniqid)
  end

  def thanks
    @person = Person.find_by(uniqid: params[:uniqid])
    redirect_to root_url if @person.nil?
  end

  def person_params
    params.expect(person: %i[first_name last_name email phone_number postcode])
  end

  private

    # At most one rejoin email per person per hour, so the form can't be used
    # to flood someone's inbox.
    def rejoin_email_allowed?(person)
      Rails.cache.write("mailing_list/rejoin_email/#{person.id}", true, expires_in: 1.hour, unless_exist: true)
    end
end
