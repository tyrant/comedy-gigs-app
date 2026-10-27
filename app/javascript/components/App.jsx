import React, { useCallback, useEffect, useMemo, useState } from 'react';
import MapView from './MapView';
import ActFilter from './ActFilter';
import useJson from '../hooks/useJson';
import useUrlState from '../hooks/useUrlState';
import {
  defaultDates, filterQuery, filtersToParams, inBounds, pluralize, readFilters, readSelection, selectionToParams
} from '../fiddly-bits';

const NO_VENUES = [];

const DateField = ({ id, label, value, onChange }) => (
  <div className="flex h-10 basis-full items-stretch rounded-md shadow-sm xs:flex-1 md:flex-none">
    <label htmlFor={id} className="flex cursor-pointer items-center rounded-l-md border border-r-0 border-gray-300 bg-gray-100 px-2 text-sm text-gray-600">
      {label}
    </label>
    <input
      type="date" id={id} name={id} value={value}
      onChange={(e) => onChange(e.target.value)}
      onClick={(e) => e.target.showPicker?.()}
      className="grow cursor-pointer rounded-r-md border border-gray-300 px-2 py-1 text-sm hover:bg-gray-100 focus:ring-1 focus:ring-purple-500 focus:outline-none xs:w-24 sm:w-auto"
      style={{ colorScheme: 'light' }}
    />
  </div>
);

const App = ({ mapStyle }) => {
  // Filters and the selected venue/gig live in the URL; the map position is
  // written there by the map itself.
  const [ filters, setFilters ] = useUrlState(readFilters, filtersToParams);
  const [ selection, setSelection ] = useUrlState(readSelection, selectionToParams);
  const [ bounds, setBounds ] = useState(null);

  const query = filterQuery(filters);
  const { data, error, loading, retry } = useJson(`/api/venues?${query}`);
  const venues = data || NO_VENUES;

  const gigsInView = useMemo(
    () => venues.reduce((sum, venue) => sum + (inBounds(bounds, venue.lat, venue.lng) ? venue.gigs : 0), 0),
    [ venues, bounds ]
  );

  // Deselect a venue the filters have just ruled out
  useEffect(() => {
    if (!data || loading || !selection.venueId) return;
    if (!data.some(venue => venue.id === selection.venueId)) setSelection({ venueId: null, gigId: null });
  }, [ data, loading ]);

  const setFilter = (name, value) => setFilters(prev => ({ ...prev, [name]: value }));
  const clearFilters = () => setFilters({ actIds: [], ...defaultDates() });

  const selectVenue = useCallback((venueId) => {
    setSelection(prev => prev.venueId === venueId ? prev : { venueId, gigId: null });
  }, []);
  const selectGig = useCallback((gigId) => setSelection(prev => ({ ...prev, gigId })), []);

  let status;
  if (loading) {
    status = <div className="size-4 animate-spin rounded-full border-b-2 border-purple-600" role="status" aria-label="Loading gigs" />;
  } else if (error) {
    status = (
      <button type="button" onClick={retry} className="text-sm text-red-600 underline">
        Loading failed; retry
      </button>
    );
  } else {
    status = <span className="text-center text-sm text-gray-600">{pluralize(gigsInView, 'gig')} in view</span>;
  }

  return (
    <div className="flex h-dvh w-screen flex-col overflow-hidden bg-gray-100">
      <header className="bg-white shadow-sm">
        <div className="flex w-full flex-wrap items-center gap-2 p-2">
          <div className="flex flex-1 flex-wrap gap-2">
            <ActFilter actIds={filters.actIds} onChange={(actIds) => setFilter('actIds', actIds)} />
            <DateField id="start_date" label="From" value={filters.startDate} onChange={(value) => setFilter('startDate', value)} />
            <DateField id="end_date" label="To" value={filters.endDate} onChange={(value) => setFilter('endDate', value)} />
          </div>

          <div className="flex items-center gap-2">
            <button type="button" onClick={clearFilters}
              className="h-10 flex-none cursor-pointer rounded-md border border-gray-300 px-3 text-sm shadow-sm hover:bg-gray-100 focus:ring-1 focus:ring-purple-500 focus:outline-none">
              Clear
            </button>
            <div className="flex h-10 min-w-24 items-center justify-center" aria-live="polite">{status}</div>
          </div>
        </div>
      </header>

      <main className="relative flex-1">
        <MapView
          mapStyle={mapStyle}
          venues={venues}
          query={query}
          selection={selection}
          onSelectVenue={selectVenue}
          onSelectGig={selectGig}
          onViewChange={setBounds}
        />
      </main>
    </div>
  );
};

export default App;
