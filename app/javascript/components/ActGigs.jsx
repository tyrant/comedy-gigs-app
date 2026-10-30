import React, { useEffect, useRef } from 'react';
import useJson from '../hooks/useJson';
import { formatGigTime, gigHref, pluralize, tourHref } from '../fiddly-bits';
import { BackButton, GigActions, GigPrice, PanelPlaceholder, SkiddleCredit, StatusBadge, TicketTiers } from './PanelBits';

const LINK_LABELS = {
  homepage: 'Website', instagram: 'Instagram', tiktok: 'TikTok', youtube: 'YouTube', twitter: 'X', facebook: 'Facebook', spotify: 'Spotify'
};

const OfficialLinks = ({ act }) => (
  <ul aria-label={`${act.name} online`} className="mt-2 flex flex-wrap gap-1.5 px-1.5">
    {act.links.map(({ kind, url }) => (
      <li key={kind}>
        <a href={url} target="_blank" rel="noopener noreferrer" data-link-kind={kind}
          className="inline-block rounded-full border border-line px-2.5 py-0.5 text-xs font-medium text-accent hover:bg-surface-2">
          {LINK_LABELS[kind] || kind}<span className="sr-only"> (opens in a new tab)</span>
        </a>
      </li>
    ))}
  </ul>
);

// The act's tours with gigs for these dates. Choosing one puts just its gigs
// on the map and in the list; choosing it again, or Escape, shows them all.
const Tours = ({ act, tours, tourId, onSelectTour }) => (
  <div className="mt-3 px-1.5">
    <h3 className="text-xs font-semibold tracking-wide text-muted uppercase">{tours.length === 1 ? 'Tour' : 'Tours'}</h3>
    <ul aria-label={`${act.name}’s tours`} className="mt-1.5 flex flex-wrap gap-1.5">
      {tours.map(tour => {
        const chosen = tour.id === tourId;
        return (
          <li key={tour.id} className="min-w-0">
            <a href={tourHref(act.id, tour.id)} data-tour-id={tour.id} aria-current={chosen ? 'true' : undefined}
              title={chosen ? 'Show all their gigs' : `Show the ${tour.name} gigs on the map`}
              onClick={(e) => { e.preventDefault(); onSelectTour(chosen ? null : tour.id); }}
              className="flex max-w-full items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-xs font-medium text-accent hover:bg-surface-2 aria-[current]:border-accent aria-[current]:bg-accent aria-[current]:text-on-accent">
              <span className="truncate">{tour.name}</span>
              <span className="shrink-0 opacity-75">{tour.gigs}</span>
              {chosen && <span aria-hidden="true" className="shrink-0">✕</span>}
            </a>
          </li>
        );
      })}
    </ul>
  </div>
);

const GigRow = ({ gig, selected, onSelectGig }) => (
  <li data-gig-id={gig.id} aria-current={selected ? 'true' : undefined}
    className="flex items-center gap-3 rounded-md px-2 py-1.5 aria-[current]:bg-accent-soft">
    <div className="min-w-0 flex-1">
      <h4 className="truncate text-sm font-medium">
        <a href={gigHref(gig.venue.id, gig.id)} data-role="gig-name" title="Show on the map"
          onClick={(e) => { e.preventDefault(); onSelectGig(gig); }}>
          {gig.name}
        </a>
      </h4>
      <p className="truncate text-xs text-muted">
        {gig.venue.name}{gig.venue.city && `, ${gig.venue.city}`}
      </p>
      <p className="flex flex-wrap items-center gap-x-2 text-xs text-muted">
        <time dateTime={gig.start_time}>{formatGigTime(gig.start_time, gig.venue.timezone)}</time>
        <GigPrice gig={gig} />
        <StatusBadge status={gig.status} />
        <SkiddleCredit gig={gig} />
      </p>
      <TicketTiers gig={gig} />
    </div>

    <GigActions gig={gig} venueId={gig.venue.id} />
  </li>
);

// An act's gigs for the current dates, wherever they are. Choosing one shows
// it on the map; the act's view stays open.
const ActGigs = ({ actId, query, gigId, tourId, searching, backLabel, focusHeading, onSearchAct, onSelectTour, onSelectGig, onBack }) => {
  const { data, error, loading, retry } = useJson(`/api/acts/${actId}/gigs?${query}`);
  const headingRef = useRef(null);

  // While switching acts, don't show the previous act's gigs
  const current = data?.act?.id === actId ? data : null;

  useEffect(() => {
    if (current && focusHeading) headingRef.current?.focus();
  }, [ current?.act.id ]);

  const back = <BackButton label={backLabel} action="close-act" onBack={onBack} />;

  if (!current) {
    return (
      <div className="act-gigs">
        <PanelPlaceholder error={error} loading={loading} retry={retry} what="this act’s gigs">{back}</PanelPlaceholder>
      </div>
    );
  }

  const { act, gigs } = current;
  const tours = current.tours || [];
  const tour = tours.find(candidate => candidate.id === tourId);

  return (
    <div className="act-gigs" aria-busy={loading}>
      <div className="px-3 pt-3 pb-2">{back}</div>

      {act.image && (
        <img src={act.image} alt="" width="352" height="198" decoding="async"
          className="aspect-video w-full bg-surface-2 object-cover object-top max-md:aspect-auto max-md:h-32" />
      )}

      <div className={`border-b border-line px-3 pb-3 ${act.image ? 'pt-3' : 'pt-0'}`}>
        <h2 ref={headingRef} tabIndex={-1} className="px-1.5 text-lg leading-6 font-bold focus:outline-none">
          {act.name}
        </h2>
        {act.description && (
          <p data-role="act-description" className="mt-1 px-1.5 text-sm whitespace-pre-line text-muted">
            {act.description}
            {act.description_url && (
              <>
                {' '}
                <a href={act.description_url} target="_blank" rel="noopener noreferrer" data-role="act-description-source"
                  className="whitespace-nowrap text-accent underline hover:text-accent-strong">
                  From Wikipedia<span className="sr-only"> (opens in a new tab)</span>
                </a>
              </>
            )}
          </p>
        )}
        {act.links.length > 0 && <OfficialLinks act={act} />}
        <div className="mt-3 px-1.5">
          <button type="button" onClick={() => onSearchAct(act.id)} disabled={searching} data-role="search-act"
            className="inline-flex cursor-pointer items-center gap-1.5 rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-on-accent hover:bg-accent-strong disabled:cursor-default disabled:bg-accent-soft disabled:text-accent-ink">
            <svg aria-hidden="true" viewBox="0 0 24 24" className="size-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" />
            </svg>
            {searching ? 'Searching their gigs' : 'Search their gigs'}
          </button>
        </div>
        {tours.length > 0 && <Tours act={act} tours={tours} tourId={tourId} onSelectTour={onSelectTour} />}
        <p className="mt-2 px-1.5 text-xs font-medium text-muted" aria-live="polite">
          {pluralize(gigs.length, 'gig')}{tour ? <> on <span className="text-fg">{tour.name}</span></> : ''} for these dates
          {tour && (
            <>
              {' · '}
              <button type="button" onClick={() => onSelectTour(null)} className="cursor-pointer text-accent underline hover:text-accent-strong">
                Show all
              </button>
            </>
          )}
        </p>
      </div>

      <ul className="p-2">
        {gigs.length === 0 && <li className="p-2 text-sm text-muted">No gigs for these dates.</li>}
        {gigs.map(gig => <GigRow key={gig.id} gig={gig} selected={gig.id === gigId} onSelectGig={onSelectGig} />)}
      </ul>
    </div>
  );
};

export default ActGigs;
