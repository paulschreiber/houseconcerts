class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :set_current_ip

  protected

    def set_current_ip
      Current.ip_address = request.remote_ip
    end

    # Devise's require_no_authentication redirects an already signed-in
    # admin visiting the sign-in page to this same path — send them to the
    # admin dashboard instead of the public homepage. Scoped to the "new"
    # action so a real sign-in (the "create" action) still lands on
    # root_path as usual.
    def after_sign_in_path_for(resource)
      return madmin_root_path if resource.is_a?(Admin) && action_name == "new"

      super
    end
end
