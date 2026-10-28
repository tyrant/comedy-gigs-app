import React, { useEffect, useRef } from 'react';
import useJson from '../hooks/useJson';
import { reduceMotion } from '../hooks/useMediaQuery';
import { formatGigTime, gigHref, pluralize } from '../fiddly-bits';

const STATUS_LABELS = { sold_out: 'Sold out', postponed: 'Postponed' };
const PLACEHOLDER_IMAGE = /venue_placeholder/;

// Gigs with the same lineup share one row of act chips:
// [ { acts: [...], gigs: [...] }, ... ]
const groupByLineup = (gigs) => {
  const groups = new Map();

  gigs.forEach(gig => {
    const key = gig.acts.map(act => act.id).sort((a, b) => a - b).join('-');
    if (!groups.has(key)) groups.set(key, { key, acts: gig.acts, gigs: [] });
    groups.get(key).gigs.push(gig);
  });

  return [ ...groups.values() ];
};

const ActChip = ({ act }) => (
  <li data-act-id={act.id} title={act.name}
    className="flex min-w-0 shrink-0 items-center gap-1.5 rounded-full bg-accent-soft py-0.5 pr-2.5 pl-0.5 text-accent-ink">
    <img src={act.image} alt={act.name} width="28" height="28" loading="lazy" decoding="async"
      className="size-7 shrink-0 rounded-full object-cover" />
    <span className="max-w-40 truncate text-xs font-medium">{act.name}</span>
  </li>
);

const GigRow = ({ gig, venue, onSelectGig }) => (
  <li data-gig-id={gig.id}
    className="flex items-center gap-3 rounded-md px-2 py-1.5 transition-colors duration-700 data-[flash]:bg-accent-soft data-[flash]:duration-0">
    <div className="min-w-0 flex-1">
      <h4 data-role="gig-link" className="truncate text-sm font-medium">
        <a href={gigHref(venue.id, gig.id)} data-role="gig-name"
          onClick={(e) => { e.preventDefault(); onSelectGig(gig.id); }}>
          {gig.name}
        </a>
      </h4>
      <p className="flex flex-wrap items-center gap-x-2 text-xs text-muted">
        <time dateTime={gig.start_time}>{formatGigTime(gig.start_time, venue.timezone)}</time>
        {STATUS_LABELS[gig.status] && (
          <span className="rounded bg-warn-soft px-1.5 text-[11px] font-medium text-warn-ink">{STATUS_LABELS[gig.status]}</span>
        )}
      </p>
    </div>

    {gig.ticket_url && (
      <a href={gig.ticket_url} data-role="ticket-url" target="_blank" rel="noopener noreferrer"
        aria-label={`Tickets for ${gig.name} (opens in a new tab)`}
        className="shrink-0 rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-on-accent hover:bg-accent-strong">
        Tickets
      </a>
    )}
  </li>
);

const BackButton = ({ onBack }) => (
  <button type="button" onClick={onBack} data-action="close-venue"
    className="inline-flex cursor-pointer items-center gap-1 rounded-md px-1.5 py-1 text-sm font-medium text-accent hover:bg-surface-2">
    <span aria-hidden="true">←</span> All venues
  </button>
);

// A venue's gigs for the current filters, fetched when it's selected.
// focusHeading moves focus to the venue's name once it loads, for keyboard and
// screen reader users who chose it from the list or the map.
const VenueGigs = ({ venueId, query, gigId, focusHeading, onSelectGig, onBack }) => {
  const { data, error, loading, retry } = useJson(`/api/venues/${venueId}/gigs?${query}`);
  const headingRef = useRef(null);
  const highlighted = useRef(null);

  // While switching venues, don't show the previous venue's gigs
  const current = data?.venue?.id === venueId ? data : null;

  useEffect(() => {
    if (current && focusHeading) headingRef.current?.focus();
  }, [ current?.venue.id ]);

  // Scroll a deep-linked gig into view once, and flash it
  useEffect(() => {
    if (!current || !gigId || highlighted.current === `${venueId}-${gigId}`) return;

    const row = document.querySelector(`#venue-details [data-gig-id="${gigId}"]`);
    if (!row) return;

    highlighted.current = `${venueId}-${gigId}`;
    row.scrollIntoView({ behavior: reduceMotion() ? 'auto' : 'smooth', block: 'center' });
    row.dataset.flash = '';
    const timer = setTimeout(() => delete row.dataset.flash, 1500);
    return () => clearTimeout(timer);
  }, [ current, gigId, venueId ]);

  if (!current) {
    return (
      <div className="venue-gigs p-3">
        <BackButton onBack={onBack} />
        {error && !loading
          ? (
            <p className="mt-3 px-1.5 text-sm text-muted">
              Couldn’t load this venue’s gigs.{' '}
              <button type="button" onClick={retry} className="cursor-pointer font-medium text-accent underline">Try again</button>
            </p>
          )
          : (
            <div className="mt-3 space-y-3 px-1.5" aria-label="Loading gigs">
              <div className="h-6 w-2/3 animate-pulse rounded bg-surface-2" />
              <div className="h-4 w-1/2 animate-pulse rounded bg-surface-2" />
              <div className="h-24 animate-pulse rounded bg-surface-2" />
            </div>
          )}
      </div>
    );
  }

  const { venue, gigs } = current;
  const hasImage = venue.image && !PLACEHOLDER_IMAGE.test(venue.image);

  return (
    <div className="venue-gigs" aria-busy={loading}>
      {hasImage && (
        <img src={venue.image} alt="" width="352" height="128" decoding="async"
          className="h-32 w-full bg-surface-2 object-cover" />
      )}

      <div className="border-b border-line p-3">
        <BackButton onBack={onBack} />
        <h2 ref={headingRef} tabIndex={-1} className="mt-2 px-1.5 text-lg leading-6 font-bold focus:outline-none">
          {venue.name}
        </h2>
        <p className="px-1.5 text-sm text-muted">
          {[ venue.address, venue.city ].filter(Boolean).join(', ')}
        </p>
        <p className="mt-1 px-1.5 text-xs font-medium text-muted">{pluralize(gigs.length, 'gig')} for these dates</p>
      </div>

      <div id="venue-gigs-scroll" className="p-2">
        {gigs.length === 0 && <p className="p-2 text-sm text-muted">No gigs here for these dates and acts.</p>}

        {groupByLineup(gigs).map(group => (
          <section key={group.key} className="border-b border-line py-2 last:border-b-0">
            {group.acts.length > 0 && (
              <ul className="no-scrollbar flex gap-1 overflow-x-auto px-2 pb-1" aria-label="Lineup">
                {group.acts.map(act => <ActChip key={act.id} act={act} />)}
              </ul>
            )}
            <ul>
              {group.gigs.map(gig => <GigRow key={gig.id} gig={gig} venue={venue} onSelectGig={onSelectGig} />)}
            </ul>
          </section>
        ))}
      </div>
    </div>
  );
};

export default VenueGigs;
