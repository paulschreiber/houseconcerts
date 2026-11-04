module Madmin
  class ApplicationController < Madmin::BaseController
    before_action :authenticate_admin_user

    def authenticate_admin_user
      authenticate_admin!
    end
  end
end
