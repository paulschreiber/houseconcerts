module Madmin
  # Editing the site's text pages (see Page), each with a live preview of the
  # page as visitors see it. The pages are fixed, so there's no New or Delete.
  class PagesController < Madmin::ApplicationController
    # The preview renders the site's page template, which uses its helpers.
    helper ::ApplicationHelper

    before_action :load_page, only: %i[edit update preview]

    # The preview is shown in an iframe on the editor's own page. It's
    # sandboxed (no scripts, its own origin), so even markup that got past
    # Page's sanitizing couldn't act as the signed-in admin.
    content_security_policy(only: :preview) do |policy|
      policy.frame_ancestors :self
      policy.sandbox
    end

    def index
      @pages = ::Page::SLUGS.map { ::Page.for(_1) }
    end

    def edit; end

    def update
      if @page.update(page_params)
        redirect_to main_app.edit_madmin_page_path(@page), notice: t("madmin.pages.saved", title: @page.title)
      else
        render :edit, status: :unprocessable_content
      end
    end

    # The page with the editor’s unsaved text, in the site’s styles.
    def preview
      @page.assign_attributes(page_params)
      render template: "shows/page", layout: "page_preview"
    end

    private

      def load_page
        @page = ::Page.for(params.expect(:id))
      end

      def page_params
        params.expect(page: %i[title body])
      end
  end
end
