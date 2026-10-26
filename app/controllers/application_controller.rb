class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :set_current_ip

  protected

    def set_current_ip
      Current.ip_address = request.remote_ip
    end

    # Admins go back to the page they were trying to reach, or to the
    # backstage dashboard: after signing in (with a password or a passkey),
    # after resetting their password, and when already signed in.
    def after_sign_in_path_for(resource)
      return super unless resource.is_a?(Admin)

      stored_location_for(resource) || madmin_root_path
    end
end
