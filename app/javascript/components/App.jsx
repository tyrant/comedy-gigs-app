import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import MapView from './MapView';
import ActFilter from './ActFilter';
import DateRange from './DateRange';
import ActGigs from './ActGigs';
import { SkiddleLogo } from './PanelBits';
import VenueGigs from './VenueGigs';
import VenueList from './VenueList';
import useJson from '../hooks/useJson';
import useMediaQuery from '../hooks/useMediaQuery';
import useTheme from '../hooks/useTheme';
import useUrlState from '../hooks/useUrlState';
import {
  defaultDates, filterQuery, filtersToParams, inView, mainRegionBounds, pluralize, readFilters, readSelection, selectionToParams
} from '../fiddly-bits';

const NO_VENUES = [];

const byGigsThenName = (a, b) => b.gigs - a.gigs || a.name.localeCompare(b.name);

const Brand = () => (
  <a href="/" className="flex shrink-0 items-center gap-2 rounded-md pr-1 font-bold tracking-tight">
    <img src="/icon.svg" alt="" width="32" height="32" className="size-8" />
    <span className="hidden sm:inline">Gigs</span>
  </a>
);

// Shows what it switches to: a moon in light mode, a sun in dark
const ThemeButton = ({ theme, onToggle }) => {
  const label = theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
  return (
    <button type="button" onClick={onToggle} aria-label={label} title={label} data-role="theme-toggle"
      className="flex size-10 shrink-0 cursor-pointer items-center justify-center rounded-md border border-line bg-surface text-muted shadow-xs hover:bg-surface-2 hover:text-fg">
      <svg viewBox="0 0 24 24" className="size-5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        {theme === 'dark'
          ? <><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" /></>
          : <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />}
      </svg>
    </button>
  );
};

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

const App = ({ mapStyles, terrainTiles }) => {
  // Filters and the selected venue/gig/act live in the URL; the map position
  // is written there by the map itself.
  const [ filters, setFilters ] = useUrlState(readFilters, filtersToParams);
  const [ selection, setSelection ] = useUrlState(readSelection, selectionToParams);
  const [ view, setView ] = useState(null); // the map's { bounds, center }
  const [ hoveredVenueId, setHoveredVenueId ] = useState(null);

  const isDesktop = useMediaQuery('(min-width: 768px)');
  const [ theme, toggleTheme ] = useTheme();
  const [ sheetOpen, setSheetOpen ] = useState(() => Boolean(readSelection().venueId || readSelection().actId));
  const [ sheetHeight, setSheetHeight ] = useState(0);
  const panelRef = useRef(null);

  // Focus follows a venue or act chosen by hand: to its name, and back after
  const focusVenue = useRef(false);
  const focusAct = useRef(false);
  const lastVenueId = useRef(null);

  // A gig chosen in an act's view is shown on the map even when the filters
  // leave its venue off it, and again each time it's chosen
  const [ actGigVenue, setActGigVenue ] = useState(null);
  const [ revealCount, setRevealCount ] = useState(0);

  // An act's tour narrows the map (and the act's list) to its gigs
  const query = filterQuery({ ...filters, tourId: selection.actId ? selection.tourId : null });
  const { data, error, loading, retry } = useJson(`/api/venues?${query}`);
  const venues = data || NO_VENUES;

  const venuesInView = useMemo(
    () => venues.filter(venue => inView(view, venue.lat, venue.lng)).sort(byGigsThenName),
    [ venues, view ]
  );
  const gigsInView = venuesInView.reduce((sum, venue) => sum + venue.gigs, 0);

  // Deselect a venue the filters have just ruled out, unless an act's view
  // put it there
  useEffect(() => {
    if (!data || loading || !selection.venueId || selection.actId) return;
    if (!data.some(venue => venue.id === selection.venueId)) setSelection(prev => ({ ...prev, venueId: null, gigId: null }));
  }, [ data, loading ]);

  // Choosing a venue (from the list or the map) closes any act's view
  const selectVenue = useCallback((venueId) => {
    focusVenue.current = Boolean(venueId);
    if (venueId) setSheetOpen(true);
    setSelection(prev => {
      if (prev.venueId) lastVenueId.current = prev.venueId;
      return prev.venueId === venueId && !prev.actId ? prev : { venueId, gigId: null, actId: null, tourId: null };
    });
  }, []);
  const selectGig = useCallback((gigId) => setSelection(prev => ({ ...prev, gigId })), []);
  const closeVenue = useCallback(() => selectVenue(null), [ selectVenue ]);

  const selectAct = useCallback((actId) => {
    focusAct.current = true;
    setSheetOpen(true);
    setSelection(prev => ({ ...prev, actId, tourId: null }));
  }, []);
  // Back to the venue it was opened from (or last showed on the map), else the list
  const closeAct = useCallback(() => {
    focusVenue.current = true;
    setSelection(prev => ({ ...prev, actId: null, tourId: null }));
  }, []);
  // Fit the map to the venues once they load after a search or a tour is
  // chosen (or a tour is linked to): where most of their gigs are
  const fitAfterLoad = useRef(Boolean(readSelection().tourId));
  const [ fitTo, setFitTo ] = useState(null); // { bounds: [ [ west, south ], [ east, north ] ] }
  useEffect(() => {
    if (!fitAfterLoad.current || loading || !data) return;
    fitAfterLoad.current = false;
    if (data.length) setFitTo({ bounds: mainRegionBounds(data) });
  }, [ data, loading ]);

  // Just this act in the comedian search, keeping the dates
  const searchAct = useCallback((actId) => {
    fitAfterLoad.current = true;
    setFilters(prev => ({ ...prev, actIds: [ actId ] }));
  }, []);
  // A tour, or null for all the act's gigs. A gig picked out may not be on it.
  const selectTour = useCallback((tourId) => {
    fitAfterLoad.current = Boolean(tourId);
    setSelection(prev => ({ ...prev, tourId, gigId: null }));
  }, []);
  const selectActGig = useCallback((gig) => {
    setActGigVenue(gig.venue);
    setRevealCount(count => count + 1);
    setSelection(prev => ({ ...prev, venueId: gig.venue.id, gigId: gig.id }));
  }, []);

  // Escape closes the act's view or the venue, unless something else (the act menu) wants it
  useEffect(() => {
    const handleKey = (e) => {
      if (e.key !== 'Escape' || e.defaultPrevented || !(selection.venueId || selection.actId)) return;
      if (e.target.closest?.('input, select, textarea, .react-select__control')) return;
      if (selection.tourId) selectTour(null); // back to all the act's gigs first
      else if (selection.actId) closeAct();
      else closeVenue();
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, [ selection.venueId, selection.actId, selection.tourId, closeAct, closeVenue, selectTour ]);


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

  const { venueId, gigId, actId } = selection;

  return (
    <div className="flex h-dvh w-screen flex-col overflow-hidden">
      <header className="relative z-20 border-b border-line bg-surface">
        <div className="flex w-full flex-wrap items-center gap-2 p-2">
          <Brand />
          <ThemeButton theme={theme} onToggle={toggleTheme} />
          <ActFilter actIds={filters.actIds} onChange={(actIds) => setFilter({ actIds })} onSelectAct={selectAct} />
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
              {sheetOpen ? 'Hide' : 'Show'} {actId ? 'act' : venueId ? 'venue' : 'list'}
            </button>
          </div>

          <div id="panel-body" className={`min-h-0 flex-1 overflow-y-auto overscroll-contain ${sheetOpen ? '' : 'max-md:hidden'}`}>
            {actId && (
              <section id="act-details" aria-label="Act">
                <ActGigs key={actId} actId={actId} query={query} gigId={gigId}
                  backLabel={venueId ? 'Back to venue' : 'All venues'} focusHeading={focusAct.current}
                  tourId={selection.tourId} onSelectTour={selectTour}
                  searching={filters.actIds.length === 1 && filters.actIds[0] === actId} onSearchAct={searchAct}
                  onSelectGig={selectActGig} onBack={closeAct} />
              </section>
            )}
            {!actId && (venueId
              ? (
                <section id="venue-details" aria-label="Venue">
                  <VenueGigs key={venueId} venueId={venueId} query={query} gigId={gigId}
                    focusHeading={focusVenue.current} onSelectGig={selectGig} onSelectAct={selectAct} onBack={closeVenue} />
                </section>
              )
              : (
                <VenueList key={lastVenueId.current} venues={venuesInView} focusVenueId={lastVenueId.current}
                  allVenues={loading ? [] : venues} center={view?.center}
                  onSelectVenue={selectVenue} onHoverVenue={setHoveredVenueId} />
              ))}
          </div>

          <footer className={`border-t border-line px-3 py-2 text-xs text-muted ${sheetOpen ? '' : 'max-md:hidden'}`}>
            Listings from Ticketmaster <span aria-hidden="true">·</span>{' '}
            <a href="https://www.eventfinda.co.nz/" className="underline hover:text-accent">Powered by Eventfinda</a>{' '}
            <span aria-hidden="true">·</span>{' '}
            <a href="https://www.skiddle.com/" className="inline-flex items-center gap-1 align-middle underline hover:text-accent">
              UK listings from
              <SkiddleLogo className="h-5" />
            </a>
          </footer>
        </aside>

        <main className="relative min-w-0 flex-1" style={{ '--sheet-inset': `${sheetHeight}px` }}>
          <MapView
            mapStyle={theme === 'dark' ? mapStyles.dark : mapStyles.light}
            theme={theme}
            terrainTiles={terrainTiles}
            fitTo={fitTo}
            venues={venues}
            selectedVenueId={venueId}
            extraVenue={actGigVenue}
            revealCount={revealCount}
            hoveredVenueId={hoveredVenueId}
            bottomInset={sheetHeight}
            onSelectVenue={selectVenue}
            onViewChange={setView}
          />
        </main>
      </div>
    </div>
  );
};

export default App;
