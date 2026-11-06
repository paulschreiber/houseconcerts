# Wraps an invalid field and lists its errors after it, each message once (a
# blank name is also too short, with the same message). Labels aren't wrapped,
# and radio buttons get no messages, so a group of them doesn't repeat its
# errors. A field with data-inline-errors="false" gets no messages either, for
# a form that lists its errors elsewhere.
ActionView::Base.field_error_proc = proc do |html_tag, instance_tag|
  field = Nokogiri::HTML.fragment(html_tag).at("input,select,textarea")
  next html_tag unless field

  html = content_tag :span, html_tag, class: "field_with_errors"
  next html if field["type"] == "radio" || field["data-inline-errors"] == "false"

  safe_join([ html, *instance_tag.error_message.uniq.map { |message| content_tag :p, message, class: "error" } ])
end
