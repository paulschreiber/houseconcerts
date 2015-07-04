class ActiveRecord::Base
  require_dependency 'model_cleaners'
  include ModelCleaners
end
