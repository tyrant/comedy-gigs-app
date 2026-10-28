import React from 'react';

// Pieces the venue and act views share

const STATUS_LABELS = { sold_out: 'Sold out', postponed: 'Postponed' };

export const StatusBadge = ({ status }) => STATUS_LABELS[status]
  ? <span className="rounded bg-warn-soft px-1.5 text-[11px] font-medium text-warn-ink">{STATUS_LABELS[status]}</span>
  : null;

export const TicketLink = ({ gig }) => gig.ticket_url
  ? (
    <a href={gig.ticket_url} data-role="ticket-url" target="_blank" rel="noopener noreferrer"
      aria-label={`Tickets for ${gig.name} (opens in a new tab)`} title="Tickets"
      className="shrink-0 rounded-md bg-accent-soft px-2 py-1 text-base leading-none hover:bg-surface-2">
      <span aria-hidden="true">🎟️</span>
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
