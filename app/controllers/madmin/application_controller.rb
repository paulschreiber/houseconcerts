module Madmin
  class ApplicationController < Madmin::BaseController
    before_action :authenticate_admin_user

    # Madmin's show page confirms a delete with t("madmin.confirmations.delete")
    # and nothing else, so the message can't say what's being deleted. Madmin
    # has no hook for it, so this fills in %{record} for that one key (see
    # config/locales/madmin.en.yml) instead of copying its whole show template.
    helper do
      def translate(key, **options)
        options = { record: delete_confirmation_description(@record) }.merge(options) if key.to_s == "madmin.confirmations.delete" && @record
        super
      end

      # ActionView's t is an alias of its own translate, so it needs
      # redefining to reach the method above.
      def t(...) = translate(...)

      # e.g. "person Jane Smith"; a resource can define its own
      # delete_confirmation_description (see RSVPResource).
      def delete_confirmation_description(record)
        return resource.delete_confirmation_description(record) if resource.respond_to?(:delete_confirmation_description)

        "#{resource.friendly_name.downcase} #{resource.display_name(record)}"
      end
    end

    def authenticate_admin_user
      authenticate_admin!
    end
  end
end
