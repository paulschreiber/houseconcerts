# The text pages (About, Musician Info). They're listed and edited by
# PagesController, so this is only the sidebar's link to the list. The pages
# are fixed, so none can be added or deleted.
class PageResource < Madmin::Resource
  attribute :slug
  attribute :title
  attribute :updated_at

  def self.readonly?
    true
  end

  menu position: 24
end
