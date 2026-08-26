module Madmin
  class RsvpsController < Madmin::ResourceController
    before_action { Current.admin_scope = params[:scope] }
  end
end
