import React, { useEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Map as MapLibreMap, Marker, NavigationControl, Popup, ScaleControl } from 'maplibre-gl';
import VenueGigs from './VenueGigs';
import { inBounds, mapViewToParams, pluralize, readMapView, writeUrlParams } from '../fiddly-bits';

// MapLibre clusters the venues on the GPU side; the markers themselves are
// HTML buttons, so they can be focused, tabbed through and clicked in specs.

const SOURCE = 'venues';
const MARKER_HEIGHT = 36; // pin plus its point, for the popup's offset
const POPUP_MARGIN = 12;

const toGeoJSON = (venues) => ({
  type: 'FeatureCollection',
  features: venues.map(venue => ({
    type: 'Feature',
    id: venue.id,
    geometry: { type: 'Point', coordinates: [ venue.lng, venue.lat ] },
    properties: { id: venue.id, name: venue.name, gigs: venue.gigs }
  }))
});

const addVenueSource = (map, data) => {
  if (map.getSource(SOURCE)) return;
  map.addSource(SOURCE, {
    type: 'geojson',
    data,
    cluster: true,
    clusterRadius: 48,
    clusterMaxZoom: 14,
    clusterProperties: { gigs: [ '+', [ 'get', 'gigs' ] ] }
  });

  // MapLibre only tiles a source some layer uses. This one draws nothing; the
  // markers are read back from its tiles.
  map.addLayer({ id: SOURCE, type: 'circle', source: SOURCE, paint: { 'circle-radius': 0, 'circle-opacity': 0 } });
};

const compactCount = (n) => n < 1000 ? String(n) : `${(n / 1000).toFixed(n < 10000 ? 1 : 0).replace(/\.0$/, '')}k`;

const venueLabel = ({ name, gigs }) => `${name} (${pluralize(gigs, 'gig')})`;
const clusterLabel = ({ point_count, gigs }) => `${pluralize(point_count, 'venue')}, ${pluralize(gigs, 'gig')}; zoom in`;

const markerButton = (className, onClick) => {
  const el = document.createElement('button');
  el.type = 'button';
  el.className = className;
  el.addEventListener('click', (e) => {
    e.stopPropagation(); // keep the map's own click (which closes the popup) out of it
    onClick();
  });
  return el;
};

// Sets the marker's label and count, touching the DOM only when they change
const updateMarker = (entry, label, count) => {
  if (entry.label === label) return;
  entry.label = label;
  const el = entry.marker.getElement();
  el.title = label;
  el.setAttribute('aria-label', label);
  el.textContent = count;
};

const clusterSize = (count) => count < 10 ? 'size-9' : count < 100 ? 'size-11' : 'size-13';

// --- The map -------------------------------------------------------------------

const MapView = ({ mapStyle, venues, query, selection, onSelectVenue, onSelectGig, onViewChange }) => {
  const containerRef = useRef(null);
  const [ map, setMap ] = useState(null);
  const [ failed, setFailed ] = useState(false);

  const markersRef = useRef(new Map()); // 'v<venue id>' or 'c<cluster id>' -> { marker, label }
  const dataRef = useRef(toGeoJSON([])); // what the source holds, for restyling
  const sentVenuesRef = useRef(null); // the venues last handed to the source
  const [ syncedVenues, setSyncedVenues ] = useState(null); // ...and once the markers show them

  const popupRef = useRef(null);
  const rootRef = useRef(null);

  const callbacks = useRef({});
  callbacks.current = { onSelectVenue, onSelectGig, onViewChange };
  const { venueId, gigId } = selection;
  const selectedRef = useRef(venueId);
  selectedRef.current = venueId;

  // Create the map, its controls and the venue popup, once
  useEffect(() => {
    const { center: [ lat, lng ], zoom } = readMapView();
    let instance;

    try {
      instance = new MapLibreMap({
        container: containerRef.current,
        style: mapStyle,
        center: [ lng, lat ],
        zoom,
        dragRotate: false,
        pitchWithRotate: false,
        touchPitch: false,
        attributionControl: { compact: true }
      });
    } catch (error) {
      console.error(error); // most likely no WebGL
      setFailed(true);
      return;
    }

    instance.touchZoomRotate.disableRotation();
    instance.keyboard.disableRotation();
    instance.addControl(new NavigationControl({ showCompass: false }), 'top-right');
    instance.addControl(new ScaleControl(), 'bottom-left');

    // A new style drops the source, so put it back each time one loads
    instance.on('style.load', () => {
      addVenueSource(instance, dataRef.current);
      setMap(instance);
    });

    const container = document.createElement('div');
    rootRef.current = createRoot(container);
    popupRef.current = new Popup({
      className: 'venue-popup-container', maxWidth: 'none', offset: MARKER_HEIGHT, focusAfterOpen: false
    }).setDOMContent(container);
    popupRef.current.on('close', () => callbacks.current.onSelectVenue(null));

    window.mapInstance = instance; // for system specs

    return () => {
      window.mapInstance = null;
      popupRef.current.off('close');
      const root = rootRef.current;
      setTimeout(() => root.unmount());
      instance.remove();
    };
  }, []);

  // Mirror the view into the URL and report the visible bounds. Panning never
  // fetches anything: every matching venue is already in the source.
  useEffect(() => {
    if (!map) return;

    // Only write the URL once the view really changes, so a fresh load leaves it clean
    let written = JSON.stringify(mapViewToParams(map.getCenter(), map.getZoom()));

    const handleMove = () => {
      const params = mapViewToParams(map.getCenter(), map.getZoom());
      if (JSON.stringify(params) !== written) {
        written = JSON.stringify(params);
        writeUrlParams(params);
      }
      callbacks.current.onViewChange(map.getBounds());
    };

    callbacks.current.onViewChange(map.getBounds());
    map.on('moveend', handleMove);
    return () => map.off('moveend', handleMove);
  }, [ map ]);

  // Hand the venues to the clustering source
  useEffect(() => {
    if (!map) return;
    dataRef.current = toGeoJSON(venues);
    sentVenuesRef.current = venues;
    map.getSource(SOURCE)?.setData(dataRef.current);
  }, [ map, venues ]);

  // Keep one HTML marker per venue or cluster in view, in step with the source
  useEffect(() => {
    if (!map) return;
    const markers = markersRef.current;

    const createVenueMarker = (props) => {
      const el = markerButton('venue-marker', () => callbacks.current.onSelectVenue(props.id));
      el.classList.toggle('is-selected', props.id === selectedRef.current);
      return new Marker({ element: el, anchor: 'bottom' });
    };

    const createClusterMarker = (props, lngLat) => {
      const el = markerButton(`cluster-marker ${clusterSize(props.point_count)}`, async () => {
        const zoom = await map.getSource(SOURCE).getClusterExpansionZoom(props.cluster_id);
        map.easeTo({ center: lngLat, zoom });
      });
      return new Marker({ element: el });
    };

    const sync = () => {
      if (!map.getSource(SOURCE) || !map.isSourceLoaded(SOURCE)) return;

      const bounds = map.getBounds();
      const seen = new Set();

      map.querySourceFeatures(SOURCE).forEach(feature => {
        const [ lng, lat ] = feature.geometry.coordinates;
        const props = feature.properties;
        const key = props.cluster ? `c${props.cluster_id}` : `v${props.id}`;
        if (seen.has(key) || !inBounds(bounds, lat, lng)) return;
        seen.add(key);

        let entry = markers.get(key);
        if (!entry) {
          const marker = props.cluster ? createClusterMarker(props, [ lng, lat ]) : createVenueMarker(props);
          entry = { marker: marker.setLngLat([ lng, lat ]).addTo(map) };
          markers.set(key, entry);
        }

        if (props.cluster) updateMarker(entry, clusterLabel(props), compactCount(props.gigs));
        else updateMarker(entry, venueLabel(props), compactCount(props.gigs));
      });

      markers.forEach((entry, key) => {
        if (seen.has(key)) return;
        entry.marker.remove();
        markers.delete(key);
      });
    };

    // Idle means the source has caught up with the last setData
    const handleIdle = () => {
      sync();
      setSyncedVenues(sentVenuesRef.current);
    };

    map.on('render', sync);
    map.on('idle', handleIdle);
    return () => {
      map.off('render', sync);
      map.off('idle', handleIdle);
    };
  }, [ map ]);

  // Highlight the selected venue's marker
  useEffect(() => {
    markersRef.current.forEach((entry, key) => {
      if (key.startsWith('v')) entry.marker.getElement().classList.toggle('is-selected', key === `v${venueId}`);
    });
  }, [ venueId, syncedVenues ]);

  // Open the popup on the selected venue, bringing it into view if need be
  useEffect(() => {
    const popup = popupRef.current;
    if (!map || !popup) return;

    if (!venueId) {
      popup.remove();
      return;
    }

    const venue = venues.find(v => v.id === venueId);
    if (!venue) return; // not loaded yet; App deselects venues the filters rule out

    popup.setLngLat([ venue.lng, venue.lat ]);
    if (!popup.isOpen()) popup.addTo(map);
    if (!inBounds(map.getBounds(), venue.lat, venue.lng)) map.easeTo({ center: [ venue.lng, venue.lat ] });
  }, [ map, venueId, venues ]);

  // Render the selected venue's gigs into the popup
  useEffect(() => {
    if (!map || !venueId) return;

    // Once the gigs arrive, pan just enough to fit the popup on screen
    const keepPopupInView = () => {
      const el = popupRef.current.isOpen() && popupRef.current.getElement();
      if (!el) return;

      const box = el.getBoundingClientRect();
      const frame = map.getContainer().getBoundingClientRect();
      // How far the popup must move; when it can't fit, keep its top left corner in view
      const dx = Math.max(0, frame.left + POPUP_MARGIN - box.left) || Math.min(0, frame.right - POPUP_MARGIN - box.right);
      const dy = Math.max(0, frame.top + POPUP_MARGIN - box.top) || Math.min(0, frame.bottom - POPUP_MARGIN - box.bottom);
      if (dx || dy) map.panBy([ -dx, -dy ]);
    };

    rootRef.current.render(
      <VenueGigs
        key={venueId}
        venueId={venueId}
        query={query}
        gigId={gigId}
        onSelectGig={(id) => callbacks.current.onSelectGig(id)}
        onRendered={keepPopupInView}
      />
    );
  }, [ map, venueId, gigId, query ]);

  if (failed) {
    return (
      <div className="flex size-full items-center justify-center p-6 text-center text-gray-600">
        This browser can’t draw the map (it needs WebGL).
      </div>
    );
  }

  return <div ref={containerRef} className="size-full" aria-busy={!map || syncedVenues !== venues} />;
};

export default MapView;
