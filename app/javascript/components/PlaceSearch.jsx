import React, { useEffect, useId, useRef, useState } from 'react';
import { debounce } from '../fiddly-bits';

// Towns, cities and regions from Photon (komoot's OpenStreetMap geocoder,
// built for search-as-you-type), for jumping the map to a place.
const PHOTON = 'https://photon.komoot.io/api/';
const LAYERS = [ 'city', 'district', 'county', 'state', 'country' ]; // not locality: farms, allotments, hamlets
const LANGUAGES = [ 'en', 'de', 'fr', 'it' ]; // Photon's; else places' own names
const LIMIT = 6;
const MIN_LENGTH = 2;

// Photon's extent is [ west, north, east, south ]
const toPlace = ({ properties: p, geometry }) => ({
  id: `${p.osm_type}${p.osm_id}`,
  name: p.name,
  detail: [ p.county, p.state, p.country ].filter((part, i, parts) => part && part !== p.name && parts.indexOf(part) === i).join(', '),
  center: geometry.coordinates,
  bounds: p.extent && [ [ p.extent[0], p.extent[3] ], [ p.extent[2], p.extent[1] ] ]
});

const searchPlaces = async (query, near, signal) => {
  const params = new URLSearchParams({ q: query, limit: LIMIT });
  const language = navigator.language?.slice(0, 2);
  if (LANGUAGES.includes(language)) params.set('lang', language);
  // Nearby places rank higher, within a radius set by the zoom: the map's,
  // so zoomed out over a country its cities beat the villages round the centre
  if (near) {
    params.set('lat', near.lat.toFixed(3));
    params.set('lon', near.lng.toFixed(3));
    params.set('zoom', Math.round(near.zoom));
  }
  LAYERS.forEach(layer => params.append('layer', layer));

  const response = await fetch(`${PHOTON}?${params}`, { signal });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  const places = (await response.json()).features.filter(feature => feature.properties.name).map(toPlace);
  // The same place can come back as both a boundary and a point
  return places.filter((place, i) => places.findIndex(other => other.name === place.name && other.detail === place.detail) === i);
};

const SearchIcon = () => (
  <svg aria-hidden="true" viewBox="0 0 24 24" className="size-4 shrink-0" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" />
  </svg>
);

// A combobox: type, arrow through the places, Enter (or a click) to go.
// near() gives the map's { lat, lng, zoom }, which nearby places are ranked up by.
const PlaceSearch = ({ near, onChoose }) => {
  const listId = useId();
  const [ query, setQuery ] = useState('');
  const [ places, setPlaces ] = useState([]);
  const [ status, setStatus ] = useState('idle'); // idle, searching, done, failed
  const [ open, setOpen ] = useState(false);
  const [ active, setActive ] = useState(-1);
  const abortRef = useRef(null);
  const inputRef = useRef(null);
  const nearRef = useRef(near); // the latest, for the debounced search
  nearRef.current = near;
  const wantedRef = useRef(''); // what's in the box now, so late answers for older text are dropped

  const search = useRef(debounce((text) => {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    if (text !== wantedRef.current) return;
    searchPlaces(text, nearRef.current(), controller.signal)
      .then(found => {
        if (text !== wantedRef.current) return;
        setPlaces(found);
        setActive(-1);
        setStatus('done');
      })
      .catch(error => {
        if (error.name === 'AbortError') return;
        console.error('Place search failed:', error);
        setPlaces([]);
        setStatus('failed');
      });
  }, 300)).current;

  useEffect(() => () => abortRef.current?.abort(), []);

  const change = (text) => {
    setQuery(text);
    setOpen(true);
    wantedRef.current = text.trim();
    if (text.trim().length < MIN_LENGTH) {
      abortRef.current?.abort();
      setPlaces([]);
      setStatus('idle');
      return;
    }
    setStatus('searching');
    search(text.trim());
  };

  const choose = (place) => {
    setQuery(place.name);
    setOpen(false);
    onChoose(place);
    inputRef.current?.blur();
  };

  const handleKey = (e) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      if (!places.length) return;
      e.preventDefault();
      setOpen(true);
      const last = places.length - 1;
      setActive(i => e.key === 'ArrowDown' ? (i >= last ? 0 : i + 1) : (i <= 0 ? last : i - 1));
    } else if (e.key === 'Enter') {
      const place = places[active] || places[0];
      if (open && place) {
        e.preventDefault();
        choose(place);
      }
    } else if (e.key === 'Escape') {
      e.preventDefault(); // the venue or act view stays open
      if (open && query) setOpen(false);
      else change('');
    }
  };

  const showList = open && query.trim().length >= MIN_LENGTH && status !== 'idle';

  return (
    <div className="relative w-72 max-w-full" data-role="place-search">
      <label className="flex h-10 items-center gap-2 rounded-md border border-line bg-surface px-2.5 text-muted shadow-sm focus-within:border-accent focus-within:ring-2 focus-within:ring-accent/30">
        <SearchIcon />
        <input ref={inputRef} type="search" value={query} placeholder="Search places…" autoComplete="off" spellCheck="false"
          role="combobox" aria-label="Search places" aria-autocomplete="list" aria-expanded={showList}
          aria-controls={listId} aria-activedescendant={showList && active >= 0 ? `${listId}-${active}` : undefined}
          onChange={(e) => change(e.target.value)} onKeyDown={handleKey}
          onFocus={() => setOpen(true)} onBlur={() => setOpen(false)}
          className="min-w-0 flex-1 bg-transparent text-sm text-fg outline-none placeholder:text-muted [&::-webkit-search-cancel-button]:cursor-pointer" />
      </label>

      {showList && (
        <ul id={listId} role="listbox" aria-label="Places"
          className="absolute inset-x-0 top-full z-20 mt-1 overflow-hidden rounded-md border border-line bg-surface py-1 shadow-lg">
          {status === 'searching' && !places.length && <li className="px-3 py-2 text-sm text-muted">Searching…</li>}
          {status === 'failed' && <li className="px-3 py-2 text-sm text-muted">Place search isn’t answering; try again soon.</li>}
          {status === 'done' && !places.length && <li className="px-3 py-2 text-sm text-muted">No places matching “{query.trim()}”</li>}
          {places.map((place, i) => (
            <li key={place.id} id={`${listId}-${i}`} role="option" aria-selected={i === active}
              onMouseDown={(e) => e.preventDefault()} // keep focus until the click lands
              onClick={() => choose(place)} onMouseEnter={() => setActive(i)}
              className="cursor-pointer px-3 py-1.5 aria-selected:bg-surface-2">
              <span className="block truncate text-sm font-medium text-fg">{place.name}</span>
              {place.detail && <span className="block truncate text-xs text-muted">{place.detail}</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default PlaceSearch;
