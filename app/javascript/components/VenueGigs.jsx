import React, { useEffect, useRef, useState } from 'react';
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

// By date, lineups come in the order of their first gig (the API sends gigs
// by date). By act, lineups go A–Z by their first act, and gigs without a
// lineup go last.
const sortGroups = (groups, sortBy) => {
  if (sortBy !== 'act') return groups;

  const leadAct = (group) => group.acts[0]?.name;
  return [ ...groups ].sort((a, b) => {
    if (!leadAct(a) || !leadAct(b)) return Boolean(leadAct(b)) - Boolean(leadAct(a));
    return leadAct(a).localeCompare(leadAct(b), undefined, { sensitivity: 'base' });
  });
};

const SORT_KEY = 'venueGigsSort';
const SORTS = [ [ 'date', 'Date' ], [ 'act', 'Act' ] ];

// The last choice, remembered between venues and visits where storage allows
const useSortBy = () => {
  const [ sortBy, setSortBy ] = useState(() => {
    try { return localStorage.getItem(SORT_KEY) === 'act' ? 'act' : 'date'; } catch { return 'date'; }
  });

  const choose = (value) => {
    setSortBy(value);
    try { localStorage.setItem(SORT_KEY, value); } catch { /* not remembered */ }
  };

  return [ sortBy, choose ];
};

const SortToggle = ({ sortBy, onChange }) => (
  <div role="group" aria-label="Sort gigs by" className="flex items-center gap-1 text-xs">
    <span className="text-muted">Sort by</span>
    {SORTS.map(([ value, label ]) => (
      <button key={value} type="button" aria-pressed={sortBy === value} data-sort={value}
        onClick={() => onChange(value)}
        className="cursor-pointer rounded-full px-2 py-0.5 font-medium text-muted hover:bg-surface-2 aria-pressed:bg-accent-soft aria-pressed:text-accent-ink">
        {label}
      </button>
    ))}
  </div>
);

const ExternalLinkIcon = () => (
  <svg aria-hidden="true" viewBox="0 0 20 20" fill="currentColor" className="size-4">
    <path d="M11 3a1 1 0 1 0 0 2h2.59l-6.3 6.3a1 1 0 1 0 1.42 1.4L15 6.42V9a1 1 0 1 0 2 0V4a1 1 0 0 0-1-1h-5Z" />
    <path d="M5 5a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2v-3a1 1 0 1 0-2 0v3H5V7h3a1 1 0 0 0 0-2H5Z" />
  </svg>
);

const hostOf = (url) => {
  try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return url; }
};

// Without a venue's own website, it links to its page on a listings site
const LISTING_SITES = [
  [ /(^|\.)ticketmaster\./, 'Ticketmaster' ],
  [ /(^|\.)ticketweb\./, 'TicketWeb' ],
  [ /(^|\.)biletix\./, 'Biletix' ],
  [ /(^|\.)eventfinda\./, 'Eventfinda' ]
];

const listingSite = (host) => LISTING_SITES.find(([ pattern ]) => pattern.test(host))?.[1];

// The link icon stays on the line with the name's last word
const NameWithLink = ({ name, url }) => {
  const split = name.lastIndexOf(' ') + 1;
  const host = hostOf(url);
  const listing = listingSite(host);

  return (
    <>
      {name.slice(0, split)}
      <span className="whitespace-nowrap">
        {name.slice(split)}
        <a href={url} data-role="venue-website" target="_blank" rel="noopener noreferrer"
          title={listing ? `on ${listing}` : host}
          aria-label={`${name} ${listing ? `on ${listing}` : 'website'} (opens in a new tab)`}
          className="ml-1.5 inline-block align-[-0.1em] text-accent hover:text-accent-strong">
          <ExternalLinkIcon />
        </a>
      </span>
    </>
  );
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
        aria-label={`Tickets for ${gig.name} (opens in a new tab)`} title="Tickets"
        className="shrink-0 rounded-md bg-accent-soft px-2 py-1 text-base leading-none hover:bg-surface-2">
        <span aria-hidden="true">🎟️</span>
      </a>
    )}
  </li>
);

// "60 Kent Terrace, Te Aro, Wellington" already names its city; others need it adding
const placeLine = ({ address, city }) => {
  if (!address) return city;
  return !city || address.toLowerCase().includes(city.toLowerCase()) ? address : `${address}, ${city}`;
};

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
  const [ sortBy, setSortBy ] = useSortBy();

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
      <div className="px-3 pt-3 pb-2">
        <BackButton onBack={onBack} />
      </div>

      {hasImage && (
        <img src={venue.image} alt="" width="352" height="128" decoding="async"
          className="h-32 w-full bg-surface-2 object-cover" />
      )}

      <div className={`border-b border-line px-3 pb-3 ${hasImage ? 'pt-3' : 'pt-0'}`}>
        <h2 ref={headingRef} tabIndex={-1} className="px-1.5 text-lg leading-6 font-bold focus:outline-none">
          {venue.website ? <NameWithLink name={venue.name} url={venue.website} /> : venue.name}
        </h2>
        <p className="px-1.5 text-sm text-muted">
          {placeLine(venue)}
        </p>
        <div className="mt-1 flex flex-wrap items-center justify-between gap-2 px-1.5">
          <p className="text-xs font-medium text-muted">{pluralize(gigs.length, 'gig')} for these dates</p>
          {gigs.length > 1 && <SortToggle sortBy={sortBy} onChange={setSortBy} />}
        </div>
      </div>

      <div id="venue-gigs-scroll" className="p-2">
        {gigs.length === 0 && <p className="p-2 text-sm text-muted">No gigs here for these dates and acts.</p>}

        {sortGroups(groupByLineup(gigs), sortBy).map(group => (
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
