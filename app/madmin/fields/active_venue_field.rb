# A show's venue field. A show can be given an active venue only, so the
# select lists active venues plus the show's current one, which stays
# selectable even if it has since been deactivated. Its search (the index
# JSON) is limited to active venues too.
class ActiveVenueField < Madmin::Fields::BelongsTo
  include CustomPartials

  def options_for_select(record)
    current = record.venue
    venues = [ current ].compact + Venue.active.excluding(current).order(:name).limit(25)
    venues.map { [ VenueResource.display_name(_1), _1.id ] }
  end

  def index_path(format: :json)
    super&.then { "#{_1}?scope=active" }
  end
end
