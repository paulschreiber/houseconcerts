module Madmin
  # The site's settings (see Settings), in a tab for each group. Each tab is a
  # SettingsForm saved on its own, so a bad value on one tab never blocks saving
  # another.
  class SettingsController < Madmin::ApplicationController
    FORMS = {
      "site" => SettingsForm::Site,
      "email" => SettingsForm::Email,
      "shows" => SettingsForm::Shows,
      "location" => SettingsForm::Location
    }.freeze

    before_action :load_tab, only: %i[show update]

    def index
      redirect_to main_app.madmin_setting_path(FORMS.keys.first)
    end

    def show
      @form = @form_class.new
    end

    def update
      @form = @form_class.new(params.expect(settings: @form_class.settings.keys))
      if @form.save
        redirect_to main_app.madmin_setting_path(@tab), notice: t("madmin.settings.saved", tab: t("madmin.settings.tabs.#{@tab}"))
      else
        render :show, status: :unprocessable_content
      end
    end

    private

      def load_tab
        @tab = params[:tab]
        @form_class = FORMS.fetch(@tab) { raise ActionController::RoutingError, "No settings tab #{@tab}" }
      end
  end
end
