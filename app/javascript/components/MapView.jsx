import React, { useMemo, useEffect, useCallback } from 'react';
import { MapContainer, TileLayer, ZoomControl, ScaleControl, useMap, useMapEvents } from 'react-leaflet';
import { debounce, getMapParamsFromUrl, updateMapUrlParams } from '../fiddly-bits';
import VenueMarkers from './VenueMarkers';

// Component to expose map instance for testing
const MapInstanceExposer = () => {
  const map = useMap();

  // Expose map instance to window for system tests
  useEffect(() => {
    if (typeof window !== 'undefined')
      window.mapInstance = map;

    // Cleanup on unmount
    return () => { 
      if (typeof window !== 'undefined')
        window.mapInstance = null;
    }; 
  }, [map]);
  
  return null;
};

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
    
    // Update map position parameters in URL
    // This won't affect venue ID or filter parameters
    updateMapUrlParams(center.lat, center.lng, zoom);
    
    // Send the raw bounds to the API
    debouncedBoundsChange(bounds);
  }, [map, debouncedBoundsChange]);

  // Initial load - trigger bounds change once map is ready
  useEffect(() => {
    if (map) handleMapMove();
  }, [map, handleMapMove]);

  return null;
};

// Initial map position setter
const InitialMapPosition = ({ center, zoom }) => {
  const map = useMap();
  
  useEffect(() => {
    // Worldcopyjump? Behold: leafletjs.com/reference.html#map-worldcopyjump
    if (center && zoom)
      map.setView(center, zoom, { animate: false, worldCopyJump: true });
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
    if (!venueMap.has(venue.id)) venueMap.set(venue.id, { venue, gigs: [] });
    
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

  const urlParams = getMapParamsFromUrl();

  const initialPosition = useMemo(() => {
    return { 
      center: [urlParams.lat || -41.959490, urlParams.lng || 171.595459],
      zoom:   urlParams.zoom || 5 
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
      <MapInstanceExposer />
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
