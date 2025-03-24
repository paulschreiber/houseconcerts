module ActiveRecord
  class Base
    require_dependency "model_cleaners"
    include ModelCleaners
  end
end
