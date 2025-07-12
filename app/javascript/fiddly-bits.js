
// Debounce helper
const debounce = (func, wait) => {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
};

// Normalize longitude to -180 to 180 range
const normalizeLongitude = (lng) => {
  // First, ensure we're working with a number
  lng = parseFloat(lng);
  if (isNaN(lng)) return 0;
  
  // Many thanks to https://stackoverflow.com/a/17323608
  lng = ((lng % 360) + 360) % 360;

  // Convert to -180 to 180 range
  lng = ((lng + 180) % 360) - 180;

  // Handle edge case where modulo might give 180
  return lng === 180 ? -180 : lng;
};

// Format date for display
const formatDate = (dateString) => {
  const date = new Date(dateString);
  return date.toLocaleString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });
};

// URL parameter handling
const getMapParamsFromUrl = () => {
  const params = new URLSearchParams(window.location.search);
  
  return {
    lat: params.get('lat') ? parseFloat(params.get('lat')) : null,
    lng: params.get('lng') ? normalizeLongitude(parseFloat(params.get('lng'))) : null,
    zoom: params.get('zoom') ? parseInt(params.get('zoom')) : null,
    venueId: params.get('venue') || null
  };
};

const updateUrlParams = (lat, lng, zoom, venueId = null) => {
  const params = new URLSearchParams(window.location.search);
  params.set('lat', lat.toFixed(6));
  params.set('lng', normalizeLongitude(lng).toFixed(6));
  params.set('zoom', zoom);
  
  // Handle venue ID parameter
  if (venueId) {
    params.set('venue', venueId);
  } else {
    params.delete('venue');
  }
  
  window.history.replaceState({}, '', `${window.location.pathname}?${params}`);
};

export { debounce, normalizeLongitude, getMapParamsFromUrl, updateUrlParams, formatDate };
