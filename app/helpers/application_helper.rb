module ApplicationHelper
  def page_title_array
    page_title = [HC_CONFIG.site_name]
    page_title.unshift @show.name if @show
    page_title
  end

  def page_title
    page_title_array.join(' » ')
  end

  def social_media_title
    if @show
      social_title = [@show.name, @show.start_date_short, HC_CONFIG.site_name]
    else
      social_title = [HC_CONFIG.site_name]
    end
    social_title.join(' » ')
  end

  def social_media_description
    if @show && !@show.artists.empty?
      description = "RSVP for the #{@show.name} house concert"
      description += " in #{@show.location}" if @show.location
      description += " on #{@show.start_date}"
      description
    else
      HC_CONFIG.meta_description
    end
  end

  def social_media_image
    return root_url + @show.artists.first.photo if @show && !@show.artists.empty?

    if current_page?(root_url)
      next_show = Show.upcoming.first
      return root_url + next_show.artists.first.photo if next_show.present? && !next_show.artists.empty?
    end

    root_url + 'concerts.png'
  end

  def svg_icon
    '/concerts.svg'
  end

  def apple_touch_icon
    '/concerts.png'
  end
end
