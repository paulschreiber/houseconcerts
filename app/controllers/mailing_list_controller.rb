class MailingListController < ApplicationController
  def index
    @person = Person.new(params[:person])

  end
end
