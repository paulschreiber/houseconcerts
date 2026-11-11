# A slug made from the record's name, via friendly_id. A rename changes the
# slug, and a blank name gets none (not the numbered candidate "2", or a UUID).
module NamedSlug
  extend ActiveSupport::Concern

  included do
    extend FriendlyId

    friendly_id :name_slug_candidates, use: :slugged

    # Defined on the model itself, not as a module method: friendly_id's
    # Slugged module, included just above, would take precedence over a
    # module's.
    def should_generate_new_friendly_id?
      name.present? && (name_changed? || super)
    end
  end

  def name_slug_candidates
    cleaned_name = name.to_s.gsub(" and", "")

    2.upto(100).inject([ cleaned_name ]) { |a, e| a << format("%<name>s %<counter>d", name: cleaned_name, counter: e) }
  end
end
