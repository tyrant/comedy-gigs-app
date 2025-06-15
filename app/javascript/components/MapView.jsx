import React from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';

// Fix for default marker icons in react-leaflet
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.7.1/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.7.1/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.7.1/dist/images/marker-shadow.png',
});

const MapView = ({ gigs }) => {
  if (!gigs || gigs.length === 0) {
    // Default to London if no gigs
    return (
      <MapContainer
        center={[51.505, -0.09]}
        zoom={13}
        style={{ height: '600px', width: '100%' }}
      >
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />
      </MapContainer>
    );
  }

  // Calculate bounds from gig locations
  const bounds = gigs.reduce(
    (acc, gig) => {
      const lat = parseFloat(gig.venue.latitude);
      const lng = parseFloat(gig.venue.longitude);
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

  return (
    <div className="h-full w-full">
      <MapContainer
        bounds={bounds}
        style={{ height: '600px', width: '100%' }}
      >
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />
        {gigs.map((gig) => (
          <Marker
            key={gig.id}
            position={[parseFloat(gig.venue.latitude), parseFloat(gig.venue.longitude)]}
          >
            <Popup>
              <div>
                <h3 className="text-lg font-semibold">{gig.name}</h3>
                <p className="text-sm text-gray-600">{gig.venue.name}</p>
                <p className="text-sm">
                  {new Date(gig.start_time).toLocaleString()}
                </p>
                <a
                  href={gig.ticket_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-600 hover:text-blue-800"
                >
                  Get Tickets
                </a>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
};

export default MapView;
