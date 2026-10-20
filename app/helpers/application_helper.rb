module ApplicationHelper
  def page_title(item = nil)
    page_title = [ Settings.site_name ]
    if item.is_a?(Show)
      page_title.unshift item.name
    elsif item
      page_title.unshift item
    end
    page_title.join(" » ")
  end

  def social_media_title(show)
    if show
      social_title = [ show.name, show.start_date_short, Settings.site_name ]
    else
      social_title = [ Settings.site_name ]
    end
    social_title.join(" » ")
  end

  def social_media_description(show)
    if show && !show.artists.empty?
      description = "Reserve seats for the #{show.event_name}"
      description += " in #{show.location}" if show.location
      description += " on #{show.start_date}"
      description
    else
      Settings.meta_description
    end
  end

  # The show's first artist's photo, or the site image when there's no show
  # or it has no artists.
  def social_media_image(show)
    photo_url = show.artists.first&.photo_url if show
    photo_url || "#{Rails.application.routes.url_helpers.root_url}concerts.png"
  end

  def canonical_url
    request.original_url.split("?").first
  end

  def svg_icon
    "/concerts.svg"
  end

  def apple_touch_icon
    "/concerts.png"
  end

  # A URL as sent to Google Analytics: link tokens (uniqid) replaced with
  # ":uniqid", and only utm_* campaign parameters kept from the query string
  # (pre-filled RSVP links can carry an email address there), so GA never sees
  # a token or personal details. UNIQID_IN_PATH is defined in
  # config/initializers/filter_parameter_logging.rb.
  def analytics_url(url)
    return if url.blank?

    uri = URI.parse(url)
    uri.path = uri.path.gsub(UNIQID_IN_PATH) { "#{Regexp.last_match(1)}:uniqid" }
    campaign_params = URI.decode_www_form(uri.query.to_s).select { |name, _| name.start_with?("utm_") }
    uri.query = campaign_params.empty? ? nil : URI.encode_www_form(campaign_params)
    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError, ArgumentError
    nil
  end
end
