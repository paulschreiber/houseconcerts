# The text pages (About, Musician Info). They're listed and edited by
# PagesController, so this resource only names them. The pages are
# fixed, so none can be added or deleted. The sidebar links to them from its
# last group (madmin/application/_navigation).
class PageResource < Madmin::Resource
  attribute :slug
  attribute :title
  attribute :updated_at

  def self.readonly?
    true
  end

  menu false
end
