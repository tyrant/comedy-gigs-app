import React, { useMemo, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, ZoomControl, ScaleControl, useMap, useMapEvents } from 'react-leaflet';
import MarkerClusterGroup from 'react-leaflet-cluster';
import L from 'leaflet';

// URL parameter handling
const getMapParamsFromUrl = () => {
  const params = new URLSearchParams(window.location.search);
  return {
    lat: parseFloat(params.get('lat')) || null,
    lng: parseFloat(params.get('lng')) || null,
    zoom: parseInt(params.get('zoom')) || null
  };
};

const updateUrlParams = (lat, lng, zoom) => {
  const params = new URLSearchParams(window.location.search);
  params.set('lat', lat.toFixed(6));
  params.set('lng', lng.toFixed(6));
  params.set('zoom', zoom);
  window.history.replaceState({}, '', `${window.location.pathname}?${params}`);
};

// Map event handler component
const MapEventHandler = () => {
  const map = useMapEvents({
    moveend: () => {
      const center = map.getCenter();
      const zoom = map.getZoom();
      updateUrlParams(center.lat, center.lng, zoom);
    },
    zoomend: () => {
      const center = map.getCenter();
      const zoom = map.getZoom();
      updateUrlParams(center.lat, center.lng, zoom);
    }
  });
  return null;
};

// Initial map position setter
const InitialMapPosition = ({ center, zoom }) => {
  const map = useMap();
  
  useEffect(() => {
    if (center && zoom) {
      map.setView(center, zoom, { animate: false });
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

// Format date for display
const formatDate = (dateString) => {
  const date = new Date(dateString);
  return date.toLocaleString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short'
  });
};

// Sort gigs by date
const sortGigsByDate = (gigs) => {
  return [...gigs].sort((a, b) => new Date(a.start_time) - new Date(b.start_time));
};

// Group gigs by venue
const groupGigsByVenue = (gigs) => {
  const venueMap = new Map();
  
  gigs.forEach(gig => {
    const venueId = gig.venue.id;
    if (!venueMap.has(venueId)) {
      venueMap.set(venueId, {
        venue: gig.venue,
        gigs: []
      });
    }
    venueMap.get(venueId).gigs.push(gig);
  });

  // Sort gigs within each venue by date
  venueMap.forEach(venue => {
    venue.gigs = sortGigsByDate(venue.gigs);
  });

  return Array.from(venueMap.values());
};

const MapView = ({ gigs }) => {
  // Memoize the grouped gigs to prevent unnecessary recalculation
  const venueGroups = useMemo(() => groupGigsByVenue(gigs), [gigs]);

  const defaultCenter = [51.505, -0.09];
  const defaultZoom = 13;
  const urlParams = getMapParamsFromUrl();

  if (!gigs || gigs.length === 0) {
    const initialCenter = urlParams.lat && urlParams.lng ? [urlParams.lat, urlParams.lng] : defaultCenter;
    const initialZoom = urlParams.zoom || defaultZoom;

    return (
      <MapContainer
        center={initialCenter}
        zoom={initialZoom}
        className="h-full w-full"
        zoomControl={false}
      >
        <MapEventHandler />
        <InitialMapPosition center={initialCenter} zoom={initialZoom} />
        <ZoomControl position="topright" />
        <ScaleControl position="bottomright" />
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />
      </MapContainer>
    );
  }

  // Calculate bounds from venue locations with padding
  const bounds = venueGroups.reduce(
    (acc, { venue }) => {
      const lat = parseFloat(venue.latitude);
      const lng = parseFloat(venue.longitude);
      return [
        [Math.min(acc[0][0], lat), Math.min(acc[0][1], lng)],
        [Math.max(acc[1][0], lat), Math.max(acc[1][1], lng)],
      ];
    },
    [
      [90, 180],
      [-90, -180],
    ]
  );

  // Add padding to bounds
  const paddingFactor = 0.1; // 10% padding
  const latDiff = bounds[1][0] - bounds[0][0];
  const lngDiff = bounds[1][1] - bounds[0][1];
  bounds[0][0] -= latDiff * paddingFactor;
  bounds[0][1] -= lngDiff * paddingFactor;
  bounds[1][0] += latDiff * paddingFactor;
  bounds[1][1] += lngDiff * paddingFactor;

  // Use URL params for initial view
  const initialCenter = urlParams.lat && urlParams.lng ? [urlParams.lat, urlParams.lng] : null;
  const initialZoom = urlParams.zoom || null;

  return (
    <div className="h-full w-full">
      <MapContainer
        bounds={initialCenter ? null : bounds}
        center={initialCenter || undefined}
        zoom={initialZoom || undefined}
        className="h-full w-full"
        zoomControl={false}
      >
        <MapEventHandler />
        {initialCenter && initialZoom && (
          <InitialMapPosition center={initialCenter} zoom={initialZoom} />
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
          {venueGroups.map(({ venue, gigs }) => (
            <Marker
              key={venue.id}
              position={[parseFloat(venue.latitude), parseFloat(venue.longitude)]}
              icon={comedyIcon}
            >
              <Popup maxWidth={350} maxHeight={500} className="venue-popup">
                <div className="w-full sm:w-[330px] relative">
                  <div className="mt-5 max-h-[420px] overflow-y-auto scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100">
                    <div className="sticky top-0 z-10 bg-white px-2 pt-2 pb-3 backdrop-blur-sm bg-opacity-90">
                      <h3 className="text-lg sm:text-xl font-bold leading-tight">{venue.name}</h3>
                      <p className="text-sm sm:text-base text-gray-600 mt-1">
                        {venue.city}, {venue.country}
                      </p>
                      <div className="absolute left-0 right-0 bottom-0 h-4 bg-gradient-to-b from-white to-transparent"></div>
                    </div>
                    <div className="space-y-4 pr-2">
                      {gigs.map(gig => (
                        <div 
                          key={gig.id} 
                          className="border-t py-2 first:border-t-0 first:pt-0 hover:bg-gray-50 px-2"
                        >
                          <h4 className="font-semibold text-gray-900">{gig.name}</h4>
                          <p className="text-sm text-gray-600 mt-1">{formatDate(gig.start_time)}</p>
                          {gig.description && (
                            <p className="text-sm text-gray-600 mt-1 line-clamp-2">{gig.description}</p>
                          )}
                          <div className="mt-2">
                            <a
                              href={gig.ticket_url}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-block px-3 py-1 bg-purple-600 text-white text-sm rounded hover:bg-purple-700 transition-colors"
                            >
                              Get Tickets
                            </a>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </Popup>
            </Marker>
          ))}
        </MarkerClusterGroup>
      </MapContainer>
    </div>
  );
};

export default MapView;
