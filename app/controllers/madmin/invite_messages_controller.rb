module Madmin
  # Writing a show's invite: its revisions, each editable until a batch
  # sends it (InviteMessage#locked?), with a live preview and test sends.
  class InviteMessagesController < Madmin::ApplicationController
    before_action :load_show
    before_action :load_invite_message, only: %i[show edit update destroy send_test]
    before_action :redirect_if_locked, only: %i[edit update]

    # The preview is shown in an iframe on the editor's own page.
    content_security_policy(only: :preview) { |policy| policy.frame_ancestors :self }

    def index
      @invite_messages = @show.invite_messages.includes(:admin).reverse
      @current = @invite_messages.first
    end

    def show; end

    # Starts from the current revision's text.
    def new
      current = @show.invite_message
      @invite_message = @show.invite_messages.new(intro: current&.intro, about: current&.about)
    end

    def edit; end

    def create
      @invite_message = @show.invite_messages.new(invite_message_params.merge(admin: current_admin))
      if @invite_message.save
        redirect_to main_app.edit_madmin_show_invite_message_path(@show, @invite_message), notice: "Saved revision #{@invite_message.revision}."
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @invite_message.update(invite_message_params)
        redirect_to main_app.edit_madmin_show_invite_message_path(@show, @invite_message), notice: "Saved revision #{@invite_message.revision}."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @invite_message.destroy
        redirect_to main_app.madmin_show_invite_messages_path(@show), notice: "Deleted revision #{@invite_message.revision}."
      else
        redirect_to main_app.madmin_show_invite_message_path(@show, @invite_message), alert: @invite_message.errors.full_messages.to_sentence
      end
    end

    # The email as a sample person would get it: a saved revision (GET), or
    # the editor's unsaved text (the form, submitted into the preview iframe).
    def preview
      invite_message = params[:id] ? load_invite_message : @show.invite_messages.new(invite_message_params)
      mail = InvitesMailer.with(show: @show, invite_message: invite_message).invite_preview.message
      render html: mail.body.decoded.html_safe, layout: false # rubocop:disable Rails/OutputSafety
    end

    # Sends this revision to the signed-in admin, as their mailing-list entry,
    # so its links work. A test send doesn't lock the revision.
    def send_test
      person = Person.find_by(email: current_admin.email)
      unless person&.can_invite?
        return redirect_back_or_to main_app.madmin_show_invite_message_path(@show, @invite_message),
                                   alert: "Add yourself (#{current_admin.email}) to the mailing list to get test sends."
      end

      InvitesMailer.with(person: person, show: @show, email_type: "test", invite_message: @invite_message).invite.deliver_later
      redirect_back_or_to main_app.madmin_show_invite_message_path(@show, @invite_message),
                          notice: "Sent a test of revision #{@invite_message.revision} to #{person.email}."
    end

    private

      def load_show
        @show = Show.friendly.find(params.expect(:show_id))
      end

      def load_invite_message
        @invite_message = @show.invite_messages.find_by!(revision: params.expect(:id))
      end

      # A sent revision is read-only; its page offers a new revision instead.
      def redirect_if_locked
        return unless @invite_message.locked?

        redirect_to main_app.madmin_show_invite_message_path(@show, @invite_message), alert: @invite_message.locked_notice
      end

      def invite_message_params
        params.expect(invite_message: %i[intro about])
      end
  end
end
