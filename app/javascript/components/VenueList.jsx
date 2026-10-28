import React, { useEffect, useRef } from 'react';
import { pluralize } from '../fiddly-bits';

const MAX_LISTED = 200;

// The venues in view, busiest first. Hovering one picks out its marker.
const VenueList = ({ venues, focusVenueId, onSelectVenue, onHoverVenue }) => {
  const listRef = useRef(null);

  // Coming back from a venue, put focus back on its entry
  useEffect(() => {
    if (focusVenueId) listRef.current?.querySelector(`[data-venue-id="${focusVenueId}"]`)?.focus();
  }, []);

  if (venues.length === 0) {
    return (
      <p className="p-4 text-sm text-muted">
        No gigs in this part of the map for these dates. Try zooming out, or widening the dates.
      </p>
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
