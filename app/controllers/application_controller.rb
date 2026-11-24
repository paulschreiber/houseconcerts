class ApplicationController < ActionController::Base
  GOOGLE_ANALYTICS_SCRIPT_HOST = "https://*.googletagmanager.com".freeze
  GOOGLE_ANALYTICS_HOSTS = [ "https://*.google-analytics.com", "https://*.analytics.google.com", GOOGLE_ANALYTICS_SCRIPT_HOST ].freeze

  # Google Analytics' hosts are only allowed when it's set up. The setting is
  # read for each request, not when the app boots.
  content_security_policy do |policy|
    if Settings.google_analytics_id.present?
      policy.directives["img-src"].push(*GOOGLE_ANALYTICS_HOSTS)
      policy.directives["connect-src"].push(*GOOGLE_ANALYTICS_HOSTS)
      policy.directives["script-src"].push(GOOGLE_ANALYTICS_SCRIPT_HOST)
    end
  end

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
