import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import MapView from './MapView';
import ActFilter from './ActFilter';
import DateRange from './DateRange';
import VenueGigs from './VenueGigs';
import VenueList from './VenueList';
import useJson from '../hooks/useJson';
import useMediaQuery from '../hooks/useMediaQuery';
import useUrlState from '../hooks/useUrlState';
import {
  defaultDates, filterQuery, filtersToParams, inBounds, pluralize, readFilters, readSelection, selectionToParams
} from '../fiddly-bits';

const NO_VENUES = [];

const byGigsThenName = (a, b) => b.gigs - a.gigs || a.name.localeCompare(b.name);

const Brand = () => (
  <a href="/" className="flex shrink-0 items-center gap-2 rounded-md pr-1 font-bold tracking-tight">
    <img src="/icon.svg" alt="" width="32" height="32" className="size-8" />
    <span className="hidden sm:inline">Comedy Gigs</span>
  </a>
);

const Status = ({ loading, error, retry, gigs, venues }) => {
  if (loading) {
    return <div className="size-4 animate-spin rounded-full border-2 border-accent border-t-transparent" role="status" aria-label="Loading gigs" />;
  }
  if (error) {
    return (
      <button type="button" onClick={retry} className="cursor-pointer text-sm text-danger underline">
        Loading failed; retry
      </button>
    );
  }
  return (
    <span className="text-sm text-muted">
      <strong className="font-semibold text-fg">{pluralize(gigs, 'gig')}</strong> at {pluralize(venues, 'venue')} in view
    </span>
  );
};

const App = ({ mapStyles }) => {
  // Filters and the selected venue/gig live in the URL; the map position is
  // written there by the map itself.
  const [ filters, setFilters ] = useUrlState(readFilters, filtersToParams);
  const [ selection, setSelection ] = useUrlState(readSelection, selectionToParams);
  const [ bounds, setBounds ] = useState(null);
  const [ hoveredVenueId, setHoveredVenueId ] = useState(null);

  const isDesktop = useMediaQuery('(min-width: 768px)');
  const isDark = useMediaQuery('(prefers-color-scheme: dark)');
  const [ sheetOpen, setSheetOpen ] = useState(() => Boolean(readSelection().venueId));
  const [ sheetHeight, setSheetHeight ] = useState(0);
  const panelRef = useRef(null);

  // Focus follows a venue chosen by hand: to its name, and back to the list after
  const focusVenue = useRef(false);
  const lastVenueId = useRef(null);

  const query = filterQuery(filters);
  const { data, error, loading, retry } = useJson(`/api/venues?${query}`);
  const venues = data || NO_VENUES;

  const venuesInView = useMemo(
    () => venues.filter(venue => inBounds(bounds, venue.lat, venue.lng)).sort(byGigsThenName),
    [ venues, bounds ]
  );
  const gigsInView = venuesInView.reduce((sum, venue) => sum + venue.gigs, 0);

  // Deselect a venue the filters have just ruled out
  useEffect(() => {
    if (!data || loading || !selection.venueId) return;
    if (!data.some(venue => venue.id === selection.venueId)) setSelection({ venueId: null, gigId: null });
  }, [ data, loading ]);

  const selectVenue = useCallback((venueId) => {
    focusVenue.current = Boolean(venueId);
    if (venueId) setSheetOpen(true);
    setSelection(prev => {
      if (prev.venueId) lastVenueId.current = prev.venueId;
      return prev.venueId === venueId ? prev : { venueId, gigId: null };
    });
  }, []);
  const selectGig = useCallback((gigId) => setSelection(prev => ({ ...prev, gigId })), []);
  const closeVenue = useCallback(() => selectVenue(null), [ selectVenue ]);

  // Escape closes the venue, unless something else (the act menu) wants it
  useEffect(() => {
    const handleKey = (e) => {
      if (e.key !== 'Escape' || e.defaultPrevented || !selection.venueId) return;
      if (e.target.closest?.('input, select, textarea, .react-select__control')) return;
      closeVenue();
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, [ selection.venueId, closeVenue ]);

  // On phones the panel is a sheet over the bottom of the map; the map keeps
  // the selected venue above it
  useEffect(() => {
    if (isDesktop) {
      setSheetHeight(0);
      return;
    }
    const observer = new ResizeObserver(([ entry ]) => setSheetHeight(Math.round(entry.borderBoxSize[0].blockSize)));
    observer.observe(panelRef.current);
    return () => observer.disconnect();
  }, [ isDesktop ]);

  const setFilter = (changes) => setFilters(prev => ({ ...prev, ...changes }));
  const clearFilters = () => setFilters({ actIds: [], ...defaultDates() });

  const { venueId, gigId } = selection;

  return (
    <div className="flex h-dvh w-screen flex-col overflow-hidden">
      <header className="relative z-20 border-b border-line bg-surface">
        <div className="flex w-full flex-wrap items-center gap-2 p-2">
          <Brand />
          <ActFilter actIds={filters.actIds} onChange={(actIds) => setFilter({ actIds })} />
          <DateRange startDate={filters.startDate} endDate={filters.endDate} onChange={setFilter} />
          <button type="button" onClick={clearFilters}
            className="h-10 shrink-0 cursor-pointer rounded-md border border-line bg-surface px-3 text-sm shadow-xs hover:bg-surface-2 max-md:order-1">
            Clear
          </button>
        </div>
      </header>

      <div className="relative flex min-h-0 flex-1">
        <aside ref={panelRef} aria-label="Gigs"
          className="absolute inset-x-0 bottom-0 z-10 flex max-h-[65dvh] flex-col rounded-t-2xl border-t border-line bg-surface shadow-[0_-8px_24px_rgb(0_0_0/0.15)] md:static md:z-auto md:max-h-none md:w-[22rem] md:shrink-0 md:rounded-none md:border-t-0 md:border-r md:shadow-none">
          <div className="flex min-h-12 items-center gap-2 border-b border-line px-3 py-2">
            <div className="flex min-w-0 flex-1 items-center" aria-live="polite">
              <Status loading={loading} error={error} retry={retry} gigs={gigsInView} venues={venuesInView.length} />
            </div>
            <button type="button" onClick={() => setSheetOpen(open => !open)} aria-expanded={sheetOpen} aria-controls="panel-body"
              className="shrink-0 cursor-pointer rounded-md px-2 py-1 text-sm font-medium text-accent hover:bg-surface-2 md:hidden">
              {sheetOpen ? 'Hide' : 'Show'} {venueId ? 'venue' : 'list'}
            </button>
          </div>

          <div id="panel-body" className={`min-h-0 flex-1 overflow-y-auto overscroll-contain ${sheetOpen ? '' : 'max-md:hidden'}`}>
            {venueId
              ? (
                <section id="venue-details" aria-label="Venue">
                  <VenueGigs key={venueId} venueId={venueId} query={query} gigId={gigId}
                    focusHeading={focusVenue.current} onSelectGig={selectGig} onBack={closeVenue} />
                </section>
              )
              : (
                <VenueList key={lastVenueId.current} venues={venuesInView} focusVenueId={lastVenueId.current}
                  onSelectVenue={selectVenue} onHoverVenue={setHoveredVenueId} />
              )}
          </div>

          <footer className={`border-t border-line px-3 py-2 text-xs text-muted ${sheetOpen ? '' : 'max-md:hidden'}`}>
            Listings from Ticketmaster <span aria-hidden="true">·</span>{' '}
            <a href="https://www.eventfinda.co.nz/" className="underline hover:text-accent">Powered by Eventfinda</a>
          </footer>
        </aside>

        <main className="relative min-w-0 flex-1" style={{ '--sheet-inset': `${sheetHeight}px` }}>
          <MapView
            mapStyle={isDark ? mapStyles.dark : mapStyles.light}
            venues={venues}
            selectedVenueId={venueId}
            hoveredVenueId={hoveredVenueId}
            bottomInset={sheetHeight}
            onSelectVenue={selectVenue}
            onViewChange={setBounds}
          />
        </main>
      </div>
    </div>
  );
};

export default App;
