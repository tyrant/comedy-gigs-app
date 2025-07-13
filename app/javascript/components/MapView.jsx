import React, { useMemo, useEffect, useCallback, useRef } from 'react';
import { MapContainer, TileLayer, ZoomControl, ScaleControl, useMap, useMapEvents } from 'react-leaflet';
import { debounce, getMapParamsFromUrl, updateUrlParams } from '../fiddly-bits';
import VenueMarkers from './VenueMarkers';

// Map event handler component
const MapEventHandler = ({ onBoundsChange }) => {
  const map = useMapEvents({
    moveend: () => handleMapMove(),
    zoomend: () => handleMapMove()
  });

  // Create a stable reference to the callback
  const stableCallback = useCallback((bounds) => {
    onBoundsChange(bounds);
  }, [onBoundsChange]);

  // Create a debounced version of the stable callback
  const debouncedBoundsChange = useMemo(
    () => debounce(stableCallback, 300),
    [stableCallback]
  );

  const handleMapMove = useCallback(() => {
    if (!map) return;

    const center = map.getCenter();
    const bounds = map.getBounds();
    const zoom = map.getZoom();
    
    // Get current URL params to preserve venue ID if present
    const { venueId } = getMapParamsFromUrl();
    
    // Update URL with center coordinates and preserve venue ID if present
    updateUrlParams(
      center.lat,
      center.lng,
      zoom,
      venueId
    );
    
    // Send the raw bounds to the API
    debouncedBoundsChange(bounds);
  }, [map, debouncedBoundsChange]);

  // Initial load - trigger bounds change once map is ready
  useEffect(() => {
    if (map) {
      handleMapMove();
    }
  }, [map, handleMapMove]);

  return null;
};

// Initial map position setter
const InitialMapPosition = ({ center, zoom }) => {
  const map = useMap();
  
  useEffect(() => {
    if (center && zoom) {
      // Add worldCopyJump option to handle antimeridian crossing smoothly
      map.setView(center, zoom, { animate: false, worldCopyJump: true });
    }
  }, [map, center, zoom]);

  return null;
};

// Helper functions moved to VenueMarkers component

// Sort gigs by date
const sortGigsByDate = (gigs) => {
  return [...gigs].sort((a, b) => new Date(a.start_time) - new Date(b.start_time));
};

// Group gigs by venue
const groupGigsByVenue = (gigs) => {
  if (!gigs) return [];

  const venueMap = new Map();

  gigs.forEach((gig) => {
    const venue = gig.venue;
    if (!venueMap.has(venue.id)) {
      venueMap.set(venue.id, { venue, gigs: [] });
    }
    venueMap.get(venue.id).gigs.push(gig);
  });

  // Sort gigs within each venue by date
  venueMap.forEach(venue => {
    venue.gigs = sortGigsByDate(venue.gigs);
  });

  return Array.from(venueMap.values());
};


const MapView = ({ gigs, onBoundsChange }) => {
  // Memoize the grouped gigs to prevent unnecessary recalculation
  const venueGroups = useMemo(() => groupGigsByVenue(gigs), [gigs]);

  // Store whether this is the first load
  const isFirstLoad = useRef(true);
  
  const defaultCenter = [-41.959490, 171.595459];
  const defaultZoom = 5;
  const urlParams = getMapParamsFromUrl();

  // Calculate initial map position
  const initialPosition = useMemo(() => {
    // If we have URL params, use those
    if (urlParams.lat && urlParams.lng) {
      return {
        center: [urlParams.lat, urlParams.lng],
        zoom: urlParams.zoom || defaultZoom
      };
    }
    
    // If we have gigs and this is the first load, calculate bounds
    if (gigs?.length > 0 && isFirstLoad.current) {
      isFirstLoad.current = false;
      
      // Calculate bounds from venue locations
      const bounds = venueGroups.reduce(
        (acc, { venue }) => {
          const lat = parseFloat(venue.latitude);
          const lng = parseFloat(venue.longitude);
          return [
            [Math.min(acc[0][0], lat), Math.min(acc[0][1], lng)],
            [Math.max(acc[1][0], lat), Math.max(acc[1][1], lng)],
          ];
        },
        [[90, 180], [-90, -180]]
      );

      return { bounds };
    }
    
    // Default fallback
    return {
      center: defaultCenter,
      zoom: defaultZoom
    };
  }, [venueGroups, urlParams.lat, urlParams.lng, urlParams.zoom]);

  return (
    <MapContainer
      {...(initialPosition.bounds
        ? { bounds: initialPosition.bounds }
        : { center: initialPosition.center, zoom: initialPosition.zoom }
      )}
      className="h-full w-full"
      zoomControl={false}
      worldCopyJump={true}
    >
      <MapEventHandler onBoundsChange={onBoundsChange} />
      {!initialPosition.bounds && initialPosition.center && initialPosition.zoom && (
        <InitialMapPosition 
          center={initialPosition.center} 
          zoom={initialPosition.zoom} 
        />
      )}
      <ZoomControl position="topright" />
      <ScaleControl position="bottomright" />
      <TileLayer
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      />
      {/* Our new VenueMarkers implementation manages markers directly with Leaflet */}
      <VenueMarkers venueGroups={venueGroups} />
    </MapContainer>
  );
};

export default MapView;
