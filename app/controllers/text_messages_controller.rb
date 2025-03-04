class TextMessagesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def receive
    TextMessagesMailer.notify(params["From"], params["Body"]).deliver_now
  end
end
