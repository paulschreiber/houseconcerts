class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :set_current_ip

  protected

  def set_current_ip
    Person.current_ip = request.remote_addr
    RSVP.current_ip = request.remote_addr
  end
end
