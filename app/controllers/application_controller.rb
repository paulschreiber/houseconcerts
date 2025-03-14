class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :set_current_ip

  protected

    def set_current_ip
      current_ip = request.remote_ip

      Person.current_ip = current_ip
      RSVP.current_ip = current_ip
    end
end
