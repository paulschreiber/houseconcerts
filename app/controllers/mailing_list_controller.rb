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
    email = params.dig(:person, :email)
    @person = Person.find_by(email: email) if email.present?

    if @person.present?
      redirect_to mailing_list_already_subscribed_path(uniqid: @person.uniqid)
      return
    end

    @person = Person.new(person_params)

    if @person.save
      redirect_to mailing_list_thanks_path(uniqid: @person.uniqid)
    else
      render :create, status: :unprocessable_content
    end
  end

  def thanks
    @person = Person.find_by(uniqid: params[:uniqid])
    redirect_to root_url if @person.nil?
  end

  def already_subscribed
    @person = Person.find_by(uniqid: params[:uniqid])
    redirect_to root_url if @person.nil?
  end

  def person_params
    params.expect(person: %i[first_name last_name email phone_number postcode])
  end
end
