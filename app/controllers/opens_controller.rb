class OpensController < ApplicationController
  def index
    person = Person.where(uniqid: params[:uniqid]).first if params[:uniqid]
    tag = params[:tag]

    Open.create(tag: tag, email: person.email, ip_address: Person.current_ip, open: true) if person && tag

    send_blank_gif
  end

  def send_blank_gif
    send_data(Base64.decode64('R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=='),
              type: 'image/gif',
              disposition: 'inline')
  end
end
