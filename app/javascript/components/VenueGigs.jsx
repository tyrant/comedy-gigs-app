import React, { useEffect, useLayoutEffect, useRef } from 'react';
import useJson from '../hooks/useJson';
import { formatGigTime, gigHref } from '../fiddly-bits';

const STATUS_LABELS = { sold_out: 'Sold out', postponed: 'Postponed' };

const reduceMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

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

const ActChip = ({ act, compact }) => (
  <div data-act-id={act.id} title={act.name}
    className={`inline-flex shrink-0 items-center overflow-hidden rounded-full bg-blue-100 p-1 transition-all duration-150 ${compact ? 'w-10 hover:w-28 hover:pr-1' : 'w-auto pr-2'}`}>
    <img src={act.image} alt={act.name} width="32" height="32" loading="lazy" decoding="async"
      className="mr-1 size-8 shrink-0 rounded-full object-cover" />
    <span className="w-full truncate text-center text-xs font-medium text-blue-800">{act.name}</span>
  </div>
);

const GigRow = ({ gig, venue, onSelectGig }) => (
  <div data-gig-id={gig.id} className="ml-1 rounded p-1 transition-colors duration-150 first:pt-0 hover:bg-gray-100">
    <div className="flex items-center justify-between">
      <div className="flex min-w-0 flex-1 flex-wrap items-center">
        <h4 data-role="gig-link" className="truncate">
          <a href={gigHref(venue.id, gig.id)} data-role="gig-name"
            onClick={(e) => { e.preventDefault(); onSelectGig(gig.id); }}
            className="text-xs font-semibold text-gray-900 transition-colors duration-150 hover:text-blue-600">
            <span data-role="gig-hash" className="invisible" aria-hidden="true"># </span>
            {gig.name}
          </a>
        </h4>
        <span className="ml-2.5 text-xs leading-3 text-gray-500">{formatGigTime(gig.start_time, venue.timezone)}</span>
        {STATUS_LABELS[gig.status] && (
          <span className="ml-2 rounded bg-amber-100 px-1.5 text-[11px] font-medium text-amber-800">{STATUS_LABELS[gig.status]}</span>
        )}
      </div>

      {gig.ticket_url && (
        <a href={gig.ticket_url} data-role="ticket-url" target="_blank" rel="noopener noreferrer"
          className="ml-2 shrink-0 rounded bg-purple-600 px-2.5 py-1 text-sm font-medium text-white transition-colors duration-150 hover:bg-purple-700">
          Tickets
        </a>
      )}
    </div>
  </div>
);

// A venue's gigs for the current filters, fetched when its popup opens.
// onRendered lets the popup re-measure itself once the content has arrived.
const VenueGigs = ({ venueId, query, gigId, onSelectGig, onRendered }) => {
  const { data, error, loading, retry } = useJson(`/api/venues/${venueId}/gigs?${query}`);
  const scrollRef = useRef(null);
  const highlighted = useRef(null);

  // While switching venues, don't show the previous venue's gigs
  const current = data?.venue?.id === venueId ? data : null;

  useLayoutEffect(() => { onRendered?.(); }, [ current, error ]);

  // Scroll a deep-linked gig into view once, and flash it
  useEffect(() => {
    if (!current || !gigId || highlighted.current === `${venueId}-${gigId}`) return;

    const row = scrollRef.current?.querySelector(`[data-gig-id="${gigId}"]`);
    if (!row) return;

    highlighted.current = `${venueId}-${gigId}`;
    row.scrollIntoView({ behavior: reduceMotion() ? 'auto' : 'smooth', block: 'center' });
    row.classList.add('bg-blue-200');
    const timer = setTimeout(() => row.classList.remove('bg-blue-200'), 2000);
    return () => clearTimeout(timer);
  }, [ current, gigId, venueId ]);

  if (!current) {
    return (
      <div className="venue-popup w-[280px] p-4 text-sm text-gray-600 sm:w-[330px]">
        {error && !loading
          ? <>Couldn’t load this venue’s gigs. <button type="button" onClick={retry} className="font-medium text-purple-700 underline">Try again</button></>
          : <div className="h-40 animate-pulse rounded bg-gray-100" aria-label="Loading gigs" />}
      </div>
    );
  }

  const { venue, gigs } = current;

  return (
    <div className="venue-popup w-[280px] overflow-hidden rounded-md bg-white shadow-lg sm:w-[330px]" aria-busy={loading}>
      <div className="relative h-40">
        <img src={venue.image} alt="" width="330" height="160" loading="lazy" decoding="async"
          className="size-full object-cover" />
        <div className="absolute inset-x-0 bottom-0 bg-gradient-to-b from-transparent to-gray-900/90 p-2 pt-10">
          <h3 className="text-lg leading-5 font-bold text-white">{venue.name}</h3>
          <p className="mt-0.5 truncate text-xs text-gray-200">{venue.address || venue.city}</p>
        </div>
      </div>

      <div ref={scrollRef} id="venue-popup-scroll-container" className="max-h-[320px] overflow-y-auto p-1 [scrollbar-width:thin]">
        {gigs.length === 0 && <p className="p-3 text-sm text-gray-600">No gigs here for these dates and acts.</p>}

        {groupByLineup(gigs).map(group => (
          <div key={group.key} className="mb-3 last:mb-0">
            <div className="no-scrollbar mt-1 flex h-10 w-full gap-1 overflow-x-auto">
              {group.acts.map(act => <ActChip key={act.id} act={act} compact={group.acts.length > 1} />)}
            </div>
            <div className="mt-1">
              {group.gigs.map(gig => <GigRow key={gig.id} gig={gig} venue={venue} onSelectGig={onSelectGig} />)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default VenueGigs;
