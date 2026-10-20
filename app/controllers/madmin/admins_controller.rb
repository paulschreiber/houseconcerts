module Madmin
  class AdminsController < Madmin::ResourceController
    def create
      super
      return unless @record.persisted?

      @record.send_welcome_instructions
      flash[:notice] = "Sent #{@record.email} a link to set their password."
    end

    def destroy
      return destroy_failed("You can’t delete your own account.") if @record == current_admin

      super
    end

    private

      # A new admin gets a random password they never see, and an email with a
      # link to set their own.
      def save_record(attributes)
        @record.password = Devise.friendly_token(32) if @record.new_record?
        super
      end
  end
end
