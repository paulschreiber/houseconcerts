module Admins
  # devise-webauthn's passkey management, with protections against a stolen
  # session quietly adding a permanent way to sign in:
  #
  # - adding a passkey requires the admin's current password
  # - the page lists existing passkeys so unknown ones can be spotted and removed
  # - the admin is emailed whenever a passkey is added or removed
  class PasskeysController < Devise::PasskeysController
    # Rendered in Madmin's layout, like the rest of the admin area. The
    # layout's partials (head tags, flash, sidebar) are found in
    # madmin/application, and the sidebar needs Madmin's nav_link_to.
    layout "madmin/application"
    helper Madmin::NavHelper

    before_action :require_current_password, only: :create

    def _prefixes
      super | [ "madmin/application" ]
    end

    def index
      @passkeys = resource.passkeys.order(:created_at)
    end

    # The page lives at index; this keeps older links working.
    def new
      redirect_to admin_passkeys_path
    end

    def create
      super
      return unless @passkey&.persisted?

      AdminMailer.passkey_added(resource, @passkey.name, request.remote_ip).deliver_later
    end

    def destroy
      # Loaded before super so its name is still available for the flash and
      # the email. The gem's destroy raises if the record isn't destroyed.
      @passkey = resource.passkeys.find(params.expect(:id))
      super
      AdminMailer.passkey_removed(resource, @passkey.name, request.remote_ip).deliver_later
    end

    private

      def after_update_path
        admin_passkeys_path
      end

      # Keeps the new passkey for the flash message and the email. It may be
      # unsaved (e.g. a blank name); the gem checks persisted? itself.
      def verify_and_save_passkey(passkey_from_params)
        @passkey = super
      end

      # Devise's hook for flash message interpolation; lets the locale name
      # the passkey (devise.passkeys.admin.passkey_created / passkey_deleted).
      def devise_i18n_options(options)
        super.merge(name: @passkey&.name)
      end

      def require_current_password
        return if resource.valid_password?(params[:current_password].to_s)

        session.delete(:webauthn_challenge)
        set_flash_message! :alert, :current_password_invalid
        redirect_to after_update_path
      end
  end
end
