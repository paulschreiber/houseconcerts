class MailingListController < ApplicationController
  def unsubscribe
    unless params[:uniqid]
      redirect_to root_url
      return
    end

    @person = Person.where(uniqid: params[:uniqid]).first
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
    @person = Person.where(email: params[:person][:email]).first if params[:person] && params[:person][:email]

    if @person.present?
      render "already_subscribed"
      return
    end

    @person = Person.new(person_params)

    if @person.save
      render "thanks"
    else
      render :create
    end
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :email, :phone_number, :postcode)
  end
end
