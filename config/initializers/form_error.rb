ActionView::Base.field_error_proc = proc do |html_tag, instance_tag|
  field = Nokogiri::HTML.fragment(html_tag).at("input,select,textarea")

  # instance_tag.object is "model"
  error_map = {}
  instance_tag.object.errors.each do |item|
    error_map[item.attribute] = item.message
  end

  html = if field
    html = content_tag :span, html_tag, class: "field_with_errors"
    error_map.each do |attribute, message|
      html += content_tag :p, message, class: "error" if html_tag.include? attribute.to_s and html_tag.exclude? "radio"
    end
    html
  else
    html_tag
  end

  html
end
