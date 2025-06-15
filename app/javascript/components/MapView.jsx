import React, { useMemo } from 'react';
import { MapContainer, TileLayer, Marker, Popup, ZoomControl, ScaleControl } from 'react-leaflet';
import MarkerClusterGroup from 'react-leaflet-cluster';
import L from 'leaflet';

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

  if (!gigs || gigs.length === 0) {
    // Default to London if no gigs
    return (
      <MapContainer
        center={[51.505, -0.09]}
        zoom={13}
        style={{ height: '600px', width: '100%' }}
        zoomControl={false}
      >
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

  return (
    <div className="h-full w-full">
      <MapContainer
        bounds={bounds}
        style={{ height: '600px', width: '100%' }}
        zoomControl={false}
      >
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
              <Popup>
                <div className="max-w-sm">
                  <h3 className="text-lg font-bold mb-2">{venue.name}</h3>
                  <p className="text-sm text-gray-600 mb-4">
                    {venue.city}, {venue.country}
                  </p>
                  
                  <div className="space-y-4">
                    {gigs.map(gig => (
                      <div key={gig.id} className="border-t pt-3 first:border-t-0 first:pt-0">
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
              </Popup>
            </Marker>
          ))}
        </MarkerClusterGroup>
      </MapContainer>
    </div>
  );
};

export default MapView;
