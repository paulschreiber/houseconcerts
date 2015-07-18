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
    HC_CONFIG.meta_description
  end

  def social_media_image
    Rails.public_path.join('concerts.png')
  end

  def svg_icon
    '/concerts.svg'
  end

  def apple_touch_icon
    '/concerts.png'
  end
end
