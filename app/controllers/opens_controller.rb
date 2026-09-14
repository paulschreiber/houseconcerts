class OpensController < ApplicationController
  def index
    tag = params[:tag]

    if tag && params[:uniqid]
      record = find_record(params[:kind], params[:uniqid])

      Open.create(tag: tag, email: record.email, ip_address: Current.ip_address, open: true) if record
    end

    send_blank_gif
  end

  def send_blank_gif
    send_data(Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="),
              type: "image/gif",
              disposition: "inline")
  end

  private

    # Every tracking pixel we generate now includes a "kind" hint so opens
    # aren't misattributed if a Person's uniqid ever collides with an
    # unrelated RSVP's (uniqid is only unique per-table, not across both).
    # Pixels from emails sent before this change won't have a kind, so we
    # fall back to the old best-effort Person-then-RSVP lookup for those.
    def find_record(kind, uniqid)
      case kind
      when "person" then Person.find_by(uniqid: uniqid)
      when "rsvp" then RSVP.find_by(uniqid: uniqid)
      else
        Person.find_by(uniqid: uniqid) || RSVP.find_by(uniqid: uniqid)
      end
    end
end
