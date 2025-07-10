import React, { useMemo, useEffect, useCallback, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, ZoomControl, ScaleControl, useMap, useMapEvents } from 'react-leaflet';
import MarkerClusterGroup from 'react-leaflet-cluster';
import L from 'leaflet';
import { debounce, getMapParamsFromUrl, updateUrlParams, formatDate } from '../fiddly-bits';

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
    
    // Update URL with center coordinates
    updateUrlParams(
      center.lat,
      center.lng,
      zoom
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

// Custom comedy marker icon
const comedyIcon = L.icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-violet.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

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

// Venue markers component with map access
const VenueMarkers = ({ venueGroups }) => {
  const map = useMap();
  
  return venueGroups.map(({ venue, gigs }) => {
    const lat = parseFloat(venue.latitude);
    const lng = parseFloat(venue.longitude);
    
    return (
      <Marker
        key={venue.id}
        position={[lat, lng]}
        icon={comedyIcon}
      >
        <Popup maxWidth={350} maxHeight={500} className="venue-popup">
          <div className="w-full sm:w-[330px] relative">
            {venue.primary_image_url && (
              <div className="w-full h-40 overflow-hidden">
                <img 
                  src={venue.primary_image_url} 
                  alt={venue.name} 
                  className="w-full h-full object-cover"
                />
              </div>
            )}
            <div className="mt-2 max-h-[420px] overflow-y-auto scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100">
              <div className="sticky top-0 z-10 bg-white px-2 pt-2 pb-3 backdrop-blur-sm bg-opacity-90">
                <h3 className="text-lg sm:text-xl font-bold leading-tight">{venue.name}</h3>
                <p className="text-sm sm:text-base text-gray-600 mt-1">
                  {venue.city}, {venue.country}
                </p>
                <div className="absolute left-0 right-0 bottom-0 h-4 bg-gradient-to-b from-white to-transparent" />
              </div>
              <div className="space-y-4 pr-2">
                {gigs.map(gig => (
                  <div 
                    key={gig.id} 
                    className="border-t py-3 first:border-t-0 first:pt-0 hover:bg-gray-50 px-2"
                  >
                    <h4 className="font-semibold text-gray-900">{gig.name}</h4>
                    <p className="text-gray-600 text-sm">
                      {formatDate(gig.start_time)}
                    </p>
                    
                    {/* Display acts with images */}
                    {gig.acts && gig.acts.length > 0 && (
                      <div className="mt-2">
                        <p className="text-xs text-gray-500 mb-1">Featuring:</p>
                        <div className="flex flex-wrap gap-2">
                          {gig.acts.map(act => (
                            <div key={act.id} className="flex items-center bg-purple-50 rounded-md p-1">
                              {act.primary_image_url && (
                                <div className="w-8 h-8 rounded-full overflow-hidden mr-1">
                                  <img 
                                    src={act.primary_image_url} 
                                    alt={act.name} 
                                    className="w-full h-full object-cover"
                                  />
                                </div>
                              )}
                              <span className="text-xs text-purple-800 font-medium">{act.name}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                    
                    {gig.ticket_url && (
                      <a
                        href={gig.ticket_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="mt-2 inline-block px-3 py-1 text-sm font-medium text-white bg-purple-600 rounded hover:bg-purple-700"
                      >
                        Get Tickets
                      </a>
                    )}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </Popup>
      </Marker>
    );
  });
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
      <MarkerClusterGroup
        chunkedLoading
        maxClusterRadius={40}
      >
        <VenueMarkers venueGroups={venueGroups} />
      </MarkerClusterGroup>
    </MapContainer>
  );
};

export default MapView;
