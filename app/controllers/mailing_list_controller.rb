class MailingListController < ApplicationController
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
