class OpensController < ApplicationController
  def index
    tag = params[:tag]

    if tag && params[:uniqid]
      record = Person.find_by(uniqid: params[:uniqid])
      record = RSVP.find_by(uniqid: params[:uniqid]) if record.nil?

      Open.create(tag: tag, email: record.email, ip_address: Current.ip_address, open: true) if record
    end

    send_blank_gif
  end

  def send_blank_gif
    send_data(Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="),
              type: "image/gif",
              disposition: "inline")
  end
end
