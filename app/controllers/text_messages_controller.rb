class TextMessagesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def receive
    NotifyMailer.text_message(params["From"], params["Body"]).deliver_now
  end
end
