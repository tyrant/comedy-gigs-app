
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

// Get filter parameters from URL
const getFilterParamsFromUrl = () => {
  const params = new URLSearchParams(window.location.search);
  
  // Parse act IDs if present
  let actIds = [];
  const actIdsParam = params.get('acts');
  if (actIdsParam) {
    // Try to parse the act IDs from the URL
    try {
      actIds = JSON.parse(decodeURIComponent(actIdsParam));
    } catch (e) {
      console.error('Failed to parse act IDs from URL', e);
    }
  }
  
  return {
    actIds: actIds,
    startDate: params.get('start') || '',
    endDate: params.get('end') || ''
  };
};

/**
 * Updates URL parameters without affecting other parameters
 * @param {Object} paramsToUpdate - Object containing parameters to update
 * @param {Object} paramsToRemove - Object containing parameters to remove
 */
const updateUrlParams = (paramsToUpdate = {}, paramsToRemove = []) => {
  const params = new URLSearchParams(window.location.search);
  
  // Update parameters
  Object.entries(paramsToUpdate).forEach(([key, value]) => {
    if (value !== null && value !== undefined) {
      // Special handling for lat/lng to ensure proper formatting
      if (key === 'lat' || key === 'lng') {
        params.set(key, parseFloat(value).toFixed(6));
      } 
      // Special handling for lng to normalize
      else if (key === 'lng') {
        params.set(key, normalizeLongitude(parseFloat(value)).toFixed(6));
      }
      // Special handling for act IDs array
      else if (key === 'acts' && Array.isArray(value) && value.length > 0) {
        params.set(key, encodeURIComponent(JSON.stringify(value)));
      }
      // All other parameters
      else if (value !== '') {
        params.set(key, value);
      }
    }
  });
  
  // Remove parameters
  paramsToRemove.forEach(key => {
    params.delete(key);
  });
  
  window.history.replaceState({}, '', `${window.location.pathname}?${params}`);
};

/**
 * Helper functions for updating specific URL parameter groups
 */

// Update map position parameters in URL
const updateMapUrlParams = (lat, lng, zoom) => {
  const paramsToUpdate = {};
  
  if (lat !== undefined && lat !== null) paramsToUpdate.lat = lat;
  if (lng !== undefined && lng !== null) paramsToUpdate.lng = lng;
  if (zoom !== undefined && zoom !== null) paramsToUpdate.zoom = zoom;
  
  updateUrlParams(paramsToUpdate, []);
};

// Update venue selection in URL
const updateVenueUrlParam = (venueId) => {
  if (venueId) {
    updateUrlParams({ venue: venueId }, []);
  } else {
    updateUrlParams({}, ['venue']);
  }
};

// Update filter parameters in URL
const updateFilterUrlParams = (filters) => {
  console.log('Updating filter URL params:', filters);
  const paramsToUpdate = {};
  const paramsToRemove = [];
  
  // Handle start date
  if (filters.startDate) {
    paramsToUpdate.start = filters.startDate;
  } else {
    paramsToRemove.push('start');
  }
  
  // Handle end date
  if (filters.endDate) {
    paramsToUpdate.end = filters.endDate;
  } else {
    paramsToRemove.push('end');
  }
  
  // Handle act IDs
  if (filters.actIds && filters.actIds.length > 0) {
    paramsToUpdate.acts = filters.actIds;
  } else {
    paramsToRemove.push('acts');
  }
  
  updateUrlParams(paramsToUpdate, paramsToRemove);
};

export { 
  debounce, 
  normalizeLongitude, 
  getMapParamsFromUrl, 
  getFilterParamsFromUrl, 
  updateUrlParams, 
  updateMapUrlParams,
  updateVenueUrlParam,
  updateFilterUrlParams,
  formatDate 
};
