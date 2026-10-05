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

    # A tracking pixel's "kind" says whether its uniqid is a Person's or an
    # RSVP's (uniqid is only unique within each table). A pixel without one
    # is looked up as a Person, then an RSVP.
    def find_record(kind, uniqid)
      case kind
      when "person" then Person.find_by(uniqid: uniqid)
      when "rsvp" then RSVP.find_by(uniqid: uniqid)
      else
        Person.find_by(uniqid: uniqid) || RSVP.find_by(uniqid: uniqid)
      end
    end
end
