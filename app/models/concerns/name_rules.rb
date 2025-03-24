module NameRules
  extend ActiveSupport::Concern

  def allowed_name_exception?
    Settings.exception_list.first_names.include?(first_name) && Settings.exception_list.last_names.include?(last_name)
  end
end
