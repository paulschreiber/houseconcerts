# For Madmin resources with a "Name" (full_name) index column: full_name isn't
# a database column, so the resource lists it in sortable_columns and this
# turns that sort into last name, then first name.
module SortsByFullName
  extend ActiveSupport::Concern

  private

    def scoped_resources
      resources = super
      return resources unless sort_column == "full_name"

      resources.reorder(last_name: sort_direction, first_name: sort_direction)
    end
end
