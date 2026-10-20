# schema.org JSON-LD for search engines (public show pages) and email
# clients (the confirmation email).
module JsonLdHelper
  # Data as a JSON-LD script tag. json_escape keeps a value like "</script>"
  # from closing the tag.
  def ld_json_tag(data)
    json = { "@context": "https://schema.org" }.merge(data).to_json
    tag.script(ERB::Util.json_escape(json).html_safe, type: "application/ld+json") # rubocop:disable Rails/OutputSafety
  end

  # A show as a MusicEvent. The address leaves out the street and postcode,
  # which only people with an RSVP see. Only a show taking RSVPs has a URL
  # and an offer, since its RSVP page redirects once the show is over.
  def ld_json_event(show)
    event = {
      "@type": "MusicEvent",
      name: "#{show.name} House Concert",
      startDate: show.start.iso8601,
      endDate: show.end.iso8601,
      doorTime: show.doors.iso8601,
      eventStatus: "https://schema.org/EventScheduled",
      eventAttendanceMode: "https://schema.org/OfflineEventAttendanceMode",
      description: show.blurb.presence,
      image: show.artists.map(&:photo_url),
      performer: show.artists.map { |artist| ld_json_person(artist) },
      location: {
        "@type": "Place",
        name: Settings.site_name,
        address: ld_json_address(show.venue).except(:streetAddress, :postalCode)
      }
    }
    if show.accepting_rsvps?
      url = rsvp_for_show_url(slug: show.slug)
      event[:url] = url
      event[:offers] = {
        "@type": "Offer",
        url: url,
        price: show.price,
        priceCurrency: "USD",
        availability: show.available? ? "https://schema.org/InStock" : "https://schema.org/SoldOut"
      }
    end
    event.compact
  end

  # An RSVP as an EventReservation, for the confirmation email. Unlike public
  # pages, it has the venue's full address.
  def ld_json_reservation(rsvp)
    show = rsvp.show
    {
      "@type": "EventReservation",
      reservationNumber: rsvp.uniqid,
      reservationStatus: "https://schema.org/ReservationConfirmed",
      underName: { "@type": "Person", name: rsvp.full_name },
      reservationFor: ld_json_event(show).deep_merge(location: { address: ld_json_address(show.venue) }),
      numSeats: rsvp.seats_reserved,
      modifiedTime: rsvp.updated_at.iso8601,
      modifyReservationUrl: modify_rsvp_url(slug: show.slug, uniqid: rsvp.uniqid),
      cancelReservationUrl: rsvp_response_url(slug: show.slug, uniqid: rsvp.uniqid, response: :no)
    }
  end

  def ld_json_person(artist)
    { "@type": "Person", name: artist.name, url: artist.url.presence, image: artist.photo_url }.compact
  end

  def ld_json_address(venue)
    {
      "@type": "PostalAddress",
      streetAddress: venue.address,
      addressLocality: venue.city,
      addressRegion: venue.province,
      postalCode: venue.postcode,
      addressCountry: venue.country
    }
  end
end
