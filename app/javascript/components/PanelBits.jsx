import React from 'react';

// Pieces the venue and act views share

const STATUS_LABELS = { sold_out: 'Sold out', postponed: 'Postponed' };

export const StatusBadge = ({ status }) => STATUS_LABELS[status]
  ? <span className="rounded bg-warn-soft px-1.5 text-[11px] font-medium text-warn-ink">{STATUS_LABELS[status]}</span>
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
