class OpensController < ApplicationController
  def index
    person = Person.find_by(uniqid: params[:uniqid]) if params[:uniqid]
    tag = params[:tag]

    Open.create(tag: tag, email: person.email, ip_address: Current.ip_address, open: true) if person && tag

    send_blank_gif
  end

  def send_blank_gif
    send_data(Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="),
              type: "image/gif",
              disposition: "inline")
  end
end
