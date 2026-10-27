// Small shared helpers: URL state, dates and geometry

export const debounce = (func, wait) => {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
};

// Normalise longitude to the -180..180 range
export const normalizeLongitude = (lng) => {
  lng = parseFloat(lng);
  if (isNaN(lng)) return 0;

  // Many thanks to https://stackoverflow.com/a/17323608
  lng = ((((lng % 360) + 360) % 360) + 180) % 360 - 180;
  return lng === 180 ? -180 : lng;
};

// Is a point inside the map's bounds? Copes with views that cross the
// antimeridian or show more than one copy of the world.
export const inBounds = (bounds, lat, lng) => {
  if (!bounds) return false;
  if (lat < bounds.getSouth() || lat > bounds.getNorth()) return false;

  const west = bounds.getWest();
  const east = bounds.getEast();
  if (east - west >= 360) return true;

  const shifted = west + ((((lng - west) % 360) + 360) % 360);
  return shifted <= east;
};

const isoDate = (date) => date.toISOString().split('T')[0];

// Default date range: today to a year from today
export const defaultDates = () => {
  const today = new Date();
  const nextYear = new Date(today);
  nextYear.setFullYear(today.getFullYear() + 1);
  return { startDate: isoDate(today), endDate: isoDate(nextYear) };
};

// --- URL state ---------------------------------------------------------------
// The URL is the source of truth on load; after that the app writes to it with
// replaceState, so every view can be shared or reloaded.

const urlParams = () => new URLSearchParams(window.location.search);

const positiveInt = (value) => {
  const n = parseInt(value, 10);
  return n > 0 ? n : null;
};

export const readFilters = () => {
  const params = urlParams();
  const defaults = defaultDates();

  return {
    actIds: params.getAll('act').map(positiveInt).filter(Boolean),
    startDate: params.get('start') || defaults.startDate,
    endDate: params.get('end') || defaults.endDate
  };
};

export const filtersToParams = ({ actIds, startDate, endDate }) => ({
  act: actIds,
  start: startDate || null,
  end: endDate || null
});

export const readSelection = () => {
  const params = urlParams();
  return { venueId: positiveInt(params.get('venue')), gigId: positiveInt(params.get('gig')) };
};

export const selectionToParams = ({ venueId, gigId }) => ({ venue: venueId, gig: venueId ? gigId : null });

export const readMapView = () => {
  const params = urlParams();
  const lat = parseFloat(params.get('lat'));
  const lng = parseFloat(params.get('lng'));
  const zoom = parseInt(params.get('zoom'), 10);

  return {
    center: [ isNaN(lat) ? -41.959490 : lat, isNaN(lng) ? 171.595459 : normalizeLongitude(lng) ],
    zoom: isNaN(zoom) ? 5 : zoom
  };
};

export const mapViewToParams = ({ lat, lng }, zoom) => ({
  lat: lat.toFixed(6),
  lng: normalizeLongitude(lng).toFixed(6),
  zoom
});

// Sets the given params, leaving the rest alone. Arrays become repeated params;
// null, undefined and empty arrays remove the param.
export const writeUrlParams = (updates) => {
  const params = urlParams();

  Object.entries(updates).forEach(([ key, value ]) => {
    params.delete(key);
    if (Array.isArray(value)) value.forEach(v => params.append(key, v));
    else if (value !== null && value !== undefined) params.set(key, value);
  });

  const query = params.toString();
  window.history.replaceState({}, '', query ? `${window.location.pathname}?${query}` : window.location.pathname);
};

// Query string for the API endpoints that take the map's filters
export const filterQuery = ({ actIds, startDate, endDate }) => {
  const params = new URLSearchParams();
  if (startDate) params.set('start_date', startDate);
  if (endDate) params.set('end_date', endDate);
  if (actIds.length) params.set('act_ids', actIds.join(','));
  return params.toString();
};

// Deep link to a gig, for its link's href
export const gigHref = (venueId, gigId) => {
  const params = urlParams();
  params.set('venue', venueId);
  params.set('gig', gigId);
  return `${window.location.pathname}?${params}`;
};

// --- Formatting --------------------------------------------------------------

// A gig's start, in its venue's time zone when known
export const formatGigTime = (startTime, timezone) => {
  const options = {
    weekday: 'short', day: 'numeric', month: 'short', year: 'numeric',
    hour: 'numeric', minute: '2-digit', hour12: true
  };

  try {
    return new Date(startTime).toLocaleString('en-US', timezone ? { ...options, timeZone: timezone } : options);
  } catch {
    return new Date(startTime).toLocaleString('en-US', options);
  }
};

export const pluralize = (count, noun) => `${count.toLocaleString()} ${noun}${count === 1 ? '' : 's'}`;
