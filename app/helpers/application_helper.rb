module ApplicationHelper
  def page_title
    page_title = [HC_CONFIG.site_name]
    page_title.join(' » ')
  end

  def social_media_title
    full_title = page_title
    if full_title.index(' » ')
      full_title.gsub("#{HC_CONFIG.site_name} » ", '')
    else
      full_title
    end
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
    if @show && !@show.artists.empty?
      return root_url + @show.artists.first.photo
    elsif current_page?(root_url)
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
