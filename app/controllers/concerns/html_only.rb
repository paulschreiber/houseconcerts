# The public RSVP and mailing-list pages are HTML only. Requests that ask for
# another format get a 406, and ones with a JSON body get a 415, instead of
# being processed, or crashing where there's no template for that format.
# Any Accept list that includes HTML (or */*) is fine, whatever its first
# choice: Turbo's form submissions count as HTML, and link previewers and
# email scanners often send */*. (Their routes also don't take a format
# suffix, so /rsvps.json is a 404.)
#
# Runs before the CSRF check, so a JSON POST gets the 415/406 rather than an
# InvalidAuthenticityToken 422.
module HtmlOnly
  extend ActiveSupport::Concern

  included do
    prepend_before_action :require_html
  end

  private

    def require_html
      if request.content_mime_type&.symbol == :json
        head :unsupported_media_type
      elsif request.formats.none? { |format| format.html? || format == Mime::ALL }
        head :not_acceptable
      end
    end
end
