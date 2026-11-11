module Madmin
  class ApplicationController < Madmin::BaseController
    before_action :authenticate_admin_user
    around_action :use_admin_locale

    def authenticate_admin_user
      authenticate_admin!
    end

    private

      # Error messages on the public forms address the visitor ("Enter your
      # first name"); the admin's name the field.
      def use_admin_locale(&)
        I18n.with_locale(:"en-admin", &)
      end
  end
end
