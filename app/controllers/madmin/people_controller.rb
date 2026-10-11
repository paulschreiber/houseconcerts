module Madmin
  class PeopleController < Madmin::ResourceController
    include MemoizesNextShow
    include SortsByFullName

    before_action { Current.admin_scope = params[:scope] }
    before_action :next_show, if: -> { action_name.in?(%w[index show]) }
    skip_before_action :set_record, only: %i[import run_import]

    # Bulk import: paste text or upload a file (see ImportPeople for the
    # formats).
    def import; end

    def run_import
      file = params[:file].presence
      file = nil unless file.respond_to?(:read)
      text = params[:text].to_s
      return import_error(t("madmin.people.import.text_and_file")) if file && text.present?

      # One byte over the limit is enough for ImportPeople to reject it.
      data = file ? file.read(Settings.import.max_bytes + 1).to_s : text
      return import_error(t("madmin.people.import.nothing_to_import")) if data.strip.empty?

      @result = ImportPeople.call(data, filename: file&.original_filename)
      render :import
    rescue ImportPeople::Error => e
      import_error(e.message)
    end

    def invite
      show = next_show
      if @record.can_invite? && show && InvitePerson.call(@record, show)
        redirect_back_or_to resource.index_path, notice: "Invited #{@record.full_name} to #{show.name}."
      else
        redirect_back_or_to resource.index_path, alert: "#{@record.full_name} can’t be invited."
      end
    end

    def rsvp_no
      show = next_show
      if @record.can_rsvp_no?(show) && show && RSVPNo.call(@record, show)
        redirect_back_or_to resource.index_path, notice: "Recorded a “no” RSVP for #{@record.full_name} for #{show.name}."
      else
        redirect_back_or_to resource.index_path, alert: "Can’t record a “no” RSVP for #{@record.full_name}."
      end
    end

    private

      def import_error(message)
        flash.now[:alert] = message
        render :import, status: :unprocessable_content
      end

      # Preload can_rsvp_no? for the whole page in one query instead of one
      # per row.
      def paginate_collection(collection)
        page, records = super
        Current.next_show_rsvpd_emails = RSVP.rsvpd_emails(@next_show) if @next_show
        [ page, records ]
      end
  end
end
