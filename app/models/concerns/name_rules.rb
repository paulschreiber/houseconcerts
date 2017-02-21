module NameRules
  extend ActiveSupport::Concern

  def allowed_name_exception?
    HC_CONFIG.exception_list.first_names.include?(first_name) && HC_CONFIG.exception_list.last_names.include?(last_name)
  end
end
