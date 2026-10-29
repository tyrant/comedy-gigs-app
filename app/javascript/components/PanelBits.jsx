import React, { useEffect, useState } from 'react';
import { formatMoney, formatPriceRange } from '../fiddly-bits';

// Pieces the venue and act views share

const STATUS_LABELS = { sold_out: 'Sold out', postponed: 'Postponed' };

export const StatusBadge = ({ status }) => STATUS_LABELS[status]
  ? <span className="rounded bg-warn-soft px-1.5 text-[11px] font-medium text-warn-ink">{STATUS_LABELS[status]}</span>
  : null;

// What tickets cost, where a source says, and a warning when some are nearly gone
export const GigPrice = ({ gig }) => (
  <>
    {gig.price && <span data-role="gig-price" className="font-medium text-fg">{formatPriceRange(gig.price)}</span>}
    {gig.few_left && <span className="rounded bg-warn-soft px-1.5 text-[11px] font-medium text-warn-ink">Few left</span>}
  </>
);

// A gig's ticket types, where there's a choice: folded away until asked for
export const TicketTiers = ({ gig }) => gig.tiers?.length > 1
  ? (
    <details data-role="ticket-tiers" className="group mt-0.5 text-xs text-muted">
      <summary className="w-fit cursor-pointer list-none text-accent hover:underline [&::-webkit-details-marker]:hidden">
        {gig.tiers.length} ticket types <span aria-hidden="true" className="inline-block transition-transform group-open:rotate-90">›</span>
      </summary>
      <ul className="mt-1 space-y-0.5 border-l-2 border-line pl-2">
        {gig.tiers.map((tier, i) => (
          <li key={i} className="flex gap-2">
            <span className={`flex min-w-0 flex-1 gap-2 ${tier.sold_out ? 'line-through opacity-60' : ''}`}>
              <span className="min-w-0 flex-1 truncate" title={tier.name}>{tier.name}</span>
              <span className="shrink-0 text-fg">
                {tier.price === null ? '' : tier.price === 0 ? 'Free' : formatMoney(tier.price, gig.price?.currency)}
              </span>
            </span>
            {tier.sold_out && <span className="shrink-0">Sold out</span>}
            {!tier.sold_out && tier.few_left && <span className="shrink-0 font-medium text-warn-ink">Few left</span>}
          </li>
        ))}
      </ul>
    </details>
  )
  : null;

const onSkiddle = (url) => {
  try { return /(^|\.)skiddle\.com$/.test(new URL(url).hostname); } catch { return false; }
};

export const TicketLink = ({ gig }) => gig.ticket_url
  ? (
    <a href={gig.ticket_url} data-role="ticket-url" target="_blank" rel="noopener noreferrer"
      aria-label={`Tickets for ${gig.name}${onSkiddle(gig.ticket_url) ? ' on Skiddle' : ''} (opens in a new tab)`}
      title={onSkiddle(gig.ticket_url) ? 'Tickets on Skiddle' : 'Tickets'}
      className="shrink-0 rounded-md bg-accent-soft px-2 py-1 text-base leading-none hover:bg-surface-2">
      <span aria-hidden="true">🎟️</span>
    </a>
  )
  : null;

const ICON_BUTTON = 'flex size-8 shrink-0 cursor-pointer items-center justify-center rounded-md text-muted hover:bg-surface-2 hover:text-fg';

const Icon = ({ children }) => (
  <svg aria-hidden="true" viewBox="0 0 24 24" className="size-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    {children}
  </svg>
);

// An .ics file for the viewer's calendar app
const CalendarLink = ({ gig }) => (
  <a href={`/gigs/${gig.id}/calendar.ics`} download data-role="add-to-calendar"
    aria-label={`Add ${gig.name} to your calendar`} title="Add to calendar" className={ICON_BUTTON}>
    <Icon>
      <rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18M12 14v4M10 16h4" />
    </Icon>
  </a>
);

// The gig's own link, through the device's share sheet where there is one,
// else copied
const ShareButton = ({ gig, venueId }) => {
  const [ copied, setCopied ] = useState(false);
  const url = `${window.location.origin}/?venue=${venueId}&gig=${gig.id}`;

  useEffect(() => {
    if (!copied) return;
    const timer = setTimeout(() => setCopied(false), 2000);
    return () => clearTimeout(timer);
  }, [ copied ]);

  const share = async () => {
    if (navigator.share) {
      try {
        await navigator.share({ title: gig.name, url });
        return;
      } catch (error) {
        if (error.name === 'AbortError') return; // the viewer closed the sheet
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
    } catch {
      window.prompt('Copy this link:', url); // no clipboard access
    }
  };

  return (
    <button type="button" onClick={share} data-role="share-gig" data-copied={copied || undefined}
      aria-label={copied ? 'Link copied' : `Share ${gig.name}`} title={copied ? 'Link copied' : 'Share'}
      className={`${ICON_BUTTON} data-copied:text-accent`}>
      <Icon>
        {copied
          ? <path d="M20 6 9 17l-5-5" />
          : <><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8" /><path d="m16 6-4-4-4 4M12 2v13" /></>}
      </Icon>
      <span className="sr-only" aria-live="polite">{copied ? 'Link copied' : ''}</span>
    </button>
  );
};

// A gig row's buttons: calendar, share and tickets
export const GigActions = ({ gig, venueId }) => (
  <div className="flex shrink-0 items-center gap-0.5">
    <CalendarLink gig={gig} />
    <ShareButton gig={gig} venueId={venueId} />
    <TicketLink gig={gig} />
  </div>
);

// Skiddle's logo is white, so it sits on a dark chip in either theme. Rows
// show just its wordmark, cropped from the full logo, which is too small to
// read at that size.
export const SKIDDLE_LOGO = '/images/skiddle-logo.svg';
const SKIDDLE_WORDMARK = '/images/skiddle-wordmark.svg';
export const SKIDDLE_CHIP = 'inline-flex rounded bg-neutral-900 align-middle';

// Skiddle's terms: credit it by name and logo wherever its listings show,
// linking to the event's Skiddle page
export const SkiddleCredit = ({ gig }) => gig.sources?.includes('skiddle')
  ? (
    <a href={onSkiddle(gig.ticket_url) ? gig.ticket_url : 'https://www.skiddle.com/'} data-role="skiddle-credit"
      target="_blank" rel="noopener noreferrer" title="Listing from Skiddle"
      className="inline-flex items-center gap-1 hover:underline">
      via
      <span className={`${SKIDDLE_CHIP} px-1 py-0.5`}>
        <img src={SKIDDLE_WORDMARK} alt="Skiddle" className="h-2.5 w-auto" />
      </span>
    </a>
  )
  : null;

export const BackButton = ({ label, action, onBack }) => (
  <button type="button" onClick={onBack} data-action={action}
    className="inline-flex cursor-pointer items-center gap-1 rounded-md px-1.5 py-1 text-sm font-medium text-accent hover:bg-surface-2">
    <span aria-hidden="true">←</span> {label}
  </button>
);

// Shown until a view's data arrives: a skeleton, or a way to retry
export const PanelPlaceholder = ({ error, loading, retry, what, children }) => (
  <div className="p-3">
    {children}
    {error && !loading
      ? (
        <p className="mt-3 px-1.5 text-sm text-muted">
          Couldn’t load {what}.{' '}
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
