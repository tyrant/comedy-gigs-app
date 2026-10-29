import React, { useEffect, useRef } from 'react';
import { distanceKm, formatDistance, pluralize } from '../fiddly-bits';

const MAX_LISTED = 200;
const NEAREST = 3;

// With nothing in view, the closest venues that do have gigs, for a way out
const NearestVenues = ({ venues, center, onSelectVenue }) => {
  const nearest = venues
    .map(venue => ({ venue, km: distanceKm(center, venue) }))
    .sort((a, b) => a.km - b.km)
    .slice(0, NEAREST);

  return (
    <div id="nearest-venues" className="px-2 pb-2">
      <h3 className="px-2 pb-1 text-xs font-semibold tracking-wide text-muted uppercase">Nearest gigs</h3>
      <ul>
        {nearest.map(({ venue, km }) => (
          <li key={venue.id}>
            <button type="button" data-venue-id={venue.id} onClick={() => onSelectVenue(venue.id)}
              className="flex w-full cursor-pointer items-center gap-3 rounded-md px-2 py-2 text-left hover:bg-surface-2">
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-medium">{venue.name}</span>
                <span className="block truncate text-xs text-muted">
                  {[ venue.city, `${formatDistance(km)} away` ].filter(Boolean).join(' · ')}
                </span>
              </span>
              <span className="shrink-0 rounded-full bg-accent-soft px-2 py-0.5 text-xs font-semibold text-accent-ink">
                {pluralize(venue.gigs, 'gig')}
              </span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
};

// The venues in view, busiest first. Hovering one picks out its marker.
// allVenues (everywhere, for the filters) and center offer the nearest
// elsewhere when none are in view.
const VenueList = ({ venues, allVenues = [], center, focusVenueId, onSelectVenue, onHoverVenue }) => {
  const listRef = useRef(null);

  // Coming back from a venue, put focus back on its entry
  useEffect(() => {
    if (focusVenueId) listRef.current?.querySelector(`[data-venue-id="${focusVenueId}"]`)?.focus();
  }, []);

  if (venues.length === 0) {
    return (
      <>
        <p className="p-4 text-sm text-muted">
          No gigs in this part of the map for these dates.{' '}
          {allVenues.length > 0 && center ? 'These are the closest:' : 'Try widening the dates, or other acts.'}
        </p>
        {allVenues.length > 0 && center && <NearestVenues venues={allVenues} center={center} onSelectVenue={onSelectVenue} />}
      </>
    );
  }

  const listed = venues.slice(0, MAX_LISTED);

  return (
    <>
      <ul ref={listRef} id="venue-list" className="p-2" onMouseLeave={() => onHoverVenue(null)}>
        {listed.map(venue => (
          <li key={venue.id}>
            <button type="button" data-venue-id={venue.id}
              onClick={() => onSelectVenue(venue.id)}
              onMouseEnter={() => onHoverVenue(venue.id)}
              onFocus={() => onHoverVenue(venue.id)}
              onBlur={() => onHoverVenue(null)}
              className="flex w-full cursor-pointer items-center gap-3 rounded-md px-2 py-2 text-left hover:bg-surface-2">
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-medium">{venue.name}</span>
                {venue.city && <span className="block truncate text-xs text-muted">{venue.city}</span>}
              </span>
              <span className="shrink-0 rounded-full bg-accent-soft px-2 py-0.5 text-xs font-semibold text-accent-ink">
                {pluralize(venue.gigs, 'gig')}
              </span>
            </button>
          </li>
        ))}
      </ul>
      {venues.length > MAX_LISTED && (
        <p className="px-4 pb-4 text-xs text-muted">
          Showing the {MAX_LISTED} busiest of {venues.length.toLocaleString()} venues. Zoom in to see the rest.
        </p>
      )}
    </>
  );
};

export default VenueList;
