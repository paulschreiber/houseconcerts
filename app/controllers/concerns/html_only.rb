# The public RSVP and mailing-list pages are HTML only. Requests that ask for
# another format get a 406, and ones with a JSON body get a 415, instead of
# being processed, or crashing where there's no template for that format.
# Turbo's form submissions count as HTML, and */* is allowed because link
# previewers and email scanners send it. (Their routes also don't take a
# format suffix, so /rsvps.json is a 404.)
module HtmlOnly
  extend ActiveSupport::Concern

  included do
    before_action :require_html
  end

  private

    def require_html
      if request.content_mime_type&.symbol == :json
        head :unsupported_media_type
      elsif !(request.format.html? || request.format == Mime::ALL)
        head :not_acceptable
      end
    end
end
