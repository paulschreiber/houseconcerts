module ApplicationHelper
  def page_title
    page_title = [HC_CONFIG.page_title]
    page_title.join(" » ")
  end
end
