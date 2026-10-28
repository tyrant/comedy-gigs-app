import React, { useEffect, useRef } from 'react';
import useJson from '../hooks/useJson';
import { formatGigTime, gigHref, pluralize } from '../fiddly-bits';
import { BackButton, PanelPlaceholder, StatusBadge, TicketLink } from './PanelBits';

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
        <StatusBadge status={gig.status} />
      </p>
    </div>

    <TicketLink gig={gig} />
  </li>
);

// An act's gigs for the current dates, wherever they are. Choosing one shows
// it on the map; the act's view stays open.
const ActGigs = ({ actId, query, gigId, backLabel, focusHeading, onSelectGig, onBack }) => {
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
        <p className="mt-2 px-1.5 text-xs font-medium text-muted">{pluralize(gigs.length, 'gig')} for these dates</p>
      </div>

      <ul className="p-2">
        {gigs.length === 0 && <li className="p-2 text-sm text-muted">No gigs for these dates.</li>}
        {gigs.map(gig => <GigRow key={gig.id} gig={gig} selected={gig.id === gigId} onSelectGig={onSelectGig} />)}
      </ul>
    </div>
  );
};

export default ActGigs;
