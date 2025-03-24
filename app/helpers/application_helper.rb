module ApplicationHelper
  def page_title(item = nil)
    page_title = [ HC_CONFIG.site_name ]
    if item.is_a?(Show)
      page_title.unshift item.name
    elsif item
      page_title.unshift item
    end
    page_title.join(" » ")
  end

  def social_media_title(show)
    if show
      social_title = [ show.name, show.start_date_short, HC_CONFIG.site_name ]
    else
      social_title = [ HC_CONFIG.site_name ]
    end
    social_title.join(" » ")
  end

  def social_media_description(show)
    if show && !show.artists.empty?
      description = "Reserve seats for the #{show.name} house concert"
      description += " in #{show.location}" if show.location
      description += " on #{show.start_date}"
      description
    else
      HC_CONFIG.meta_description
    end
  end

  def social_media_image(show)
    return root_url + show.artists.first.photo if show && !show.artists.empty?

    if current_page?(root_url)
      next_show = Show.upcoming.first
      return root_url + next_show.artists.first.photo if next_show.present? && !next_show.artists.empty?
    end

    "#{root_url}concerts.png"
  end

  def svg_icon
    "/concerts.svg"
  end

  def apple_touch_icon
    "/concerts.png"
  end
end
