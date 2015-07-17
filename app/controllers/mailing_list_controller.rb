class MailingListController < ApplicationController
  def unsubscribe
    redirect_to root_url and return unless params[:uniqid]

    @person = Person.where(uniqid: params[:uniqid]).first
    redirect_to root_url and return if @person.nil?

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
    # look for an existing reservation
    if params[:person] && params[:person][:email]
      @person = Person.where(email: params[:person][:email]).first
    end

    if @person.present?
      render 'already_subscribed' and return
    end

    @person = Person.new(person_params)

    if @person.save
      render 'thanks' and return
    end
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :email, :postcode)
  end
end
