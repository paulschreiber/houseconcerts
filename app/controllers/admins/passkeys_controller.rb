module Admins
  # devise-webauthn's passkey management, with protections against a stolen
  # session quietly adding a permanent way to sign in:
  #
  # - adding a passkey requires the admin's current password
  # - the page lists existing passkeys so unknown ones can be spotted and removed
  # - the admin is emailed whenever a passkey is added or removed
  class PasskeysController < Devise::PasskeysController
    before_action :require_current_password, only: :create

    def new
      @passkeys = resource.passkeys.order(:created_at)
    end

    def create
      existing_ids = resource.passkeys.ids
      super
      resource.passkeys.where.not(id: existing_ids).find_each do |passkey|
        AdminMailer.passkey_added(resource, passkey.name, request.remote_ip).deliver_later
      end
    end

    def destroy
      passkey = resource.passkeys.find_by(id: params[:id])
      super
      return unless passkey && !resource.passkeys.exists?(passkey.id)

      AdminMailer.passkey_removed(resource, passkey.name, request.remote_ip).deliver_later
    end

    private

      def require_current_password
        return if resource.valid_password?(params[:current_password].to_s)

        session.delete(:webauthn_challenge)
        set_flash_message! :alert, :current_password_invalid
        redirect_to after_update_path
      end
  end
end
