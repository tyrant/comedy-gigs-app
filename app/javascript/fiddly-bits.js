
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

// Format date for display (legacy function - maintains backward compatibility)
const formatDate = (dateString) => {
  const date = new Date(dateString);
  return date.toLocaleString('en-US', {
    year: 'numeric',
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });
};

// Format date with timezone awareness
const formatDateWithTimezone = (dateString, timezone = null) => {
  const date = new Date(dateString);
  
  // If no timezone provided, use the legacy formatting
  if (!timezone) {
    return formatDate(dateString);
  }
  
  try {
    return date.toLocaleString('en-US', {
      year: 'numeric',
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
      timeZone: timezone
    });
  } catch (error) {
    console.warn(`Invalid timezone '${timezone}', falling back to default formatting:`, error);
    return formatDate(dateString);
  }
};

// Format date in venue's timezone for gig display
const formatGigTime = (gigStartTime, venue) => {
  if (!venue || !venue.timezone) {
    return formatDate(gigStartTime);
  }
  
  return formatDateWithTimezone(gigStartTime, venue.timezone);
};

// URL parameter handling
const getMapParamsFromUrl = () => {
  const params = new URLSearchParams(window.location.search);
  
  return {
    lat: params.get('lat') ? parseFloat(params.get('lat')) : null,
    lng: params.get('lng') ? normalizeLongitude(parseFloat(params.get('lng'))) : null,
    zoom: params.get('zoom') ? parseInt(params.get('zoom')) : null,
    venueId: params.get('venue') || null,
    gigId: params.get('gig') || null
  };
};

// Get filter parameters from URL
const getFilterParamsFromUrl = () => {
  const params = new URLSearchParams(window.location.search);
  
  // Default dates: today to one year from today
  const today = new Date();
  const oneYearFromToday = new Date(today);
  oneYearFromToday.setFullYear(today.getFullYear() + 1);
  
  const defaultStartDate = today.toISOString().split('T')[0]; // YYYY-MM-DD format
  const defaultEndDate = oneYearFromToday.toISOString().split('T')[0];

  return {
    actIds: params.getAll('act')
              .map(id => parseInt(id, 10))
              .filter(id => !isNaN(id)) || [],
    startDate: params.get('start') || defaultStartDate,
    endDate: params.get('end') || defaultEndDate
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

      if (key === 'lat') {
        params.set(key, parseFloat(value).toFixed(6));
      }
      else if (key === 'lng') {
        params.set(key, normalizeLongitude(parseFloat(value)).toFixed(6));
      }
      else if (key === 'act' && Array.isArray(value) && value.length > 0) {
        params.delete('act');
        value.forEach(actId => params.append('act', actId));
      }
      
      else {
        params.set(key, value);
      }
    }
  });
  
  // Remove parameters
  paramsToRemove.forEach(key => params.delete(key));
  
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
  if (venueId) updateUrlParams({ venue: venueId }, []);
  else         updateUrlParams({}, ['venue']);
};

// Update gig selection in URL
const updateGigUrlParam = (gigId) => {
  if (gigId) updateUrlParams({ gig: gigId }, []);
  else       updateUrlParams({}, ['gig']);
};

// Update both venue and gig in URL (for gig deep-linking)
const updateVenueAndGigUrlParams = (venueId, gigId) => {
  const paramsToUpdate = {};
  const paramsToRemove = [];
  
  if (venueId) paramsToUpdate.venue = venueId;
  else         paramsToRemove.push('venue');
  
  if (gigId) paramsToUpdate.gig = gigId;
  else       paramsToRemove.push('gig');
  
  updateUrlParams(paramsToUpdate, paramsToRemove);
};

// Update filter parameters in URL
const updateFilterUrlParams = (filters) => {
  const paramsToUpdate = {};
  const paramsToRemove = [];
  
  // Handle start date
  if (filters.startDate) paramsToUpdate.start = filters.startDate;
  else                   paramsToRemove.push('start');
  
  // Handle end date
  if (filters.endDate) paramsToUpdate.end = filters.endDate;
  else                 paramsToRemove.push('end');
  
  // Handle act IDs 
  if (filters.actIds && filters.actIds.length > 0) paramsToUpdate.act = filters.actIds;
  else                                             paramsToRemove.push('act');
    
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
  updateGigUrlParam,
  updateVenueAndGigUrlParams,
  updateFilterUrlParams,
  formatDate,
  formatDateWithTimezone,
  formatGigTime
};
