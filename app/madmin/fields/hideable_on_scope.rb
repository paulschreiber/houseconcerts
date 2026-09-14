# Shared by field classes that only exist to hide themselves as an index
# column on certain Current.admin_scope values and otherwise behave exactly
# like their parent field class. Handles the two bits of boilerplate that
# come with that: to_partial_path resolves from self.class, so any action
# this subclass doesn't define its own view for has to be redirected back to
# another field's partial; and visible? needs to consult #hidden_on_index?
# before falling back to the normal per-action default.
module HideableOnScope
  extend ActiveSupport::Concern

  class_methods do
    def delegate_partial(action, to:)
      delegated_partials[action.to_s] = to
    end

    def delegated_partials
      @delegated_partials ||= {}
    end
  end

  def to_partial_path(name)
    if (field_type = self.class.delegated_partials[name.to_s])
      return "/madmin/fields/#{field_type}/#{name}"
    end

    super
  end

  def visible?(action)
    return false if action.to_sym == :index && hidden_on_index?

    super
  end
end
