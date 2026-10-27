import React, { useEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { MapContainer, TileLayer, ZoomControl, ScaleControl, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet.markercluster';
import VenueGigs from './VenueGigs';
import { mapViewToParams, pluralize, readMapView, writeUrlParams } from '../fiddly-bits';

// --- Marker icons ------------------------------------------------------------
// The pin image with the venue's gig count drawn on it, built once per count.

const MARKER_IMAGE = '/images/map-marker-2-32.png';
const iconCache = new Map();

const markerImage = new Promise((resolve, reject) => {
  const img = new Image();
  img.onload = () => resolve(img);
  img.onerror = reject;
  img.src = MARKER_IMAGE;
});

const countIcon = (img, count) => {
  if (iconCache.has(count)) return iconCache.get(count);

  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 32;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0, 32, 32);

  const fontSize = count > 99 ? 9 : count > 9 ? 11 : 13;
  ctx.font = `bold ${fontSize}px Arial`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.lineWidth = 2;
  ctx.strokeStyle = 'white';
  ctx.fillStyle = '#8A2BE2';
  ctx.strokeText(String(count), 16, 12.5);
  ctx.fillText(String(count), 16, 12.5);

  const icon = L.icon({ iconUrl: canvas.toDataURL(), iconSize: [ 32, 32 ], iconAnchor: [ 18, 32 ], popupAnchor: [ 0, -36 ] });
  iconCache.set(count, icon);
  return icon;
};

const markerTitle = (venue) => `${venue.name} (${pluralize(venue.gigs, 'gig')})`;

// --- Map behaviour -----------------------------------------------------------

// Mirrors the view into the URL and reports the visible bounds. Panning never
// fetches anything: every matching venue is already on the map.
const ViewTracker = ({ onViewChange }) => {
  const map = useMap();

  useEffect(() => {
    window.mapInstance = map; // for system specs

    const handleMove = () => {
      writeUrlParams(mapViewToParams(map.getCenter(), map.getZoom()));
      onViewChange(map.getBounds());
    };

    onViewChange(map.getBounds());
    map.on('moveend', handleMove);
    return () => {
      map.off('moveend', handleMove);
      window.mapInstance = null;
    };
  }, [ map, onViewChange ]);

  return null;
};

// Clustered venue markers, plus the one popup that shows the selected venue's
// gigs. The popup content is a single React root, re-rendered as the
// selection or filters change.
const VenueLayer = ({ venues, query, selection, onSelectVenue, onSelectGig }) => {
  const map = useMap();
  const clusterRef = useRef(null);
  const markersRef = useRef(new Map()); // venue ID -> marker
  const popupRef = useRef(null);
  const rootRef = useRef(null);
  const [ markersReady, setMarkersReady ] = useState(0); // bumped after each marker sync
  const callbacks = useRef({});
  callbacks.current = { onSelectVenue, onSelectGig };

  // One cluster group and one popup for the map's lifetime
  useEffect(() => {
    const cluster = L.markerClusterGroup({ chunkedLoading: true, maxClusterRadius: 40, showCoverageOnHover: false });
    map.addLayer(cluster);
    clusterRef.current = cluster;

    const container = document.createElement('div');
    rootRef.current = createRoot(container);
    popupRef.current = L.popup({
      className: 'venue-popup-container', maxWidth: 340, minWidth: 280, offset: [ 0, 10 ], autoPanPadding: [ 20, 20 ]
    }).setContent(container);

    // Closing the popup deselects the venue, unless it was only closed to reopen elsewhere
    popupRef.current.on('remove', () => setTimeout(() => {
      if (!map.hasLayer(popupRef.current)) callbacks.current.onSelectVenue(null);
    }));

    return () => {
      map.removeLayer(cluster);
      map.closePopup(popupRef.current);
      const root = rootRef.current;
      setTimeout(() => root.unmount());
    };
  }, [ map ]);

  // Add, update and remove markers to match the venue list
  useEffect(() => {
    let cancelled = false;

    markerImage.then(img => {
      if (cancelled) return;

      const markers = markersRef.current;
      const seen = new Set();
      const added = [];

      venues.forEach(venue => {
        seen.add(venue.id);
        let marker = markers.get(venue.id);

        if (!marker) {
          marker = L.marker([ venue.lat, venue.lng ], { icon: countIcon(img, venue.gigs), title: markerTitle(venue) });
          marker.on('click', () => callbacks.current.onSelectVenue(venue.id));
          marker.gigCount = venue.gigs;
          markers.set(venue.id, marker);
          added.push(marker);
        } else if (marker.gigCount !== venue.gigs) {
          marker.gigCount = venue.gigs;
          marker.options.title = markerTitle(venue);
          marker.setIcon(countIcon(img, venue.gigs));
          // Leaflet only applies the title when it creates the element, not when reusing it
          marker.getElement()?.setAttribute('title', marker.options.title);
        }
      });

      const removed = [ ...markers.keys() ].filter(id => !seen.has(id));
      clusterRef.current.removeLayers(removed.map(id => markers.get(id)));
      removed.forEach(id => markers.delete(id));
      clusterRef.current.addLayers(added);

      setMarkersReady(n => n + 1);
    });

    return () => { cancelled = true; };
  }, [ venues ]);

  // Open the popup on the selected venue, revealing it from inside a cluster if need be
  const { venueId, gigId } = selection;

  useEffect(() => {
    const popup = popupRef.current;
    const marker = venueId && markersRef.current.get(venueId);

    if (!marker) {
      if (!venueId) map.closePopup(popup);
      return;
    }

    clusterRef.current.zoomToShowLayer(marker, () => {
      popup.setLatLng(marker.getLatLng());
      if (!map.hasLayer(popup)) popup.openOn(map);
    });
  }, [ venueId, markersReady ]);

  // Render the selected venue's gigs into the popup
  useEffect(() => {
    if (!venueId) return;

    rootRef.current.render(
      <VenueGigs
        key={venueId}
        venueId={venueId}
        query={query}
        gigId={gigId}
        onSelectGig={(id) => callbacks.current.onSelectGig(id)}
        onRendered={() => popupRef.current.isOpen() && popupRef.current.update()}
      />
    );
  }, [ venueId, gigId, query ]);

  return null;
};

const MapView = ({ venues, query, selection, onSelectVenue, onSelectGig, onViewChange }) => {
  const [ initialView ] = useState(readMapView);

  return (
    <MapContainer center={initialView.center} zoom={initialView.zoom} className="size-full" zoomControl={false} worldCopyJump>
      <ViewTracker onViewChange={onViewChange} />
      <ZoomControl position="topright" />
      <ScaleControl position="bottomright" />
      <TileLayer
        url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      />
      <VenueLayer venues={venues} query={query} selection={selection} onSelectVenue={onSelectVenue} onSelectGig={onSelectGig} />
    </MapContainer>
  );
};

export default MapView;
