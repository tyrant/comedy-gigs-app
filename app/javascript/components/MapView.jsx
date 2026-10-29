import React, { useEffect, useRef, useState } from 'react';
import { GeolocateControl, Map as MapLibreMap, Marker, NavigationControl, ScaleControl } from 'maplibre-gl';
import { inBounds, mapViewToParams, pluralize, readMapView, writeUrlParams } from '../fiddly-bits';
import { reduceMotion } from '../hooks/useMediaQuery';

// MapLibre clusters the venues on the GPU side; the markers themselves are
// HTML buttons, so they can be focused, tabbed through and clicked in specs.

const SOURCE = 'venues';
const EDGE_MARGIN = 48; // how close to the edge a selected venue may sit before the map recentres
const NEAR_ME_ZOOM = 12; // about a city's worth of venues around you

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
    e.stopPropagation(); // the map has no click handling of its own to trigger
    onClick();
  });
  return el;
};

// A cluster's size says how many venues it holds, its colour how many gigs:
// cool for a few, hot for lots
const clusterSize = (venues) => venues < 10 ? 'size-9' : venues < 100 ? 'size-11' : 'size-13';
const clusterHeat = (gigs) => gigs < 25 ? 'is-few' : gigs < 100 ? 'is-some' : gigs < 500 ? 'is-many' : 'is-lots';
const clusterClasses = ({ point_count, gigs }) => [ clusterSize(point_count), clusterHeat(gigs) ];

// Sets the marker's label and count (and a cluster's size and colour classes),
// touching the DOM only when they change. Classes are swapped one by one:
// MapLibre's own (maplibregl-marker...) position the marker.
const updateMarker = (entry, label, count, classes = []) => {
  if (entry.label === label) return;
  entry.label = label;
  const el = entry.marker.getElement();
  el.title = label;
  el.setAttribute('aria-label', label);
  el.textContent = count;
  el.classList.remove(...(entry.classes || []));
  el.classList.add(...classes);
  entry.classes = classes;
};

const motion = () => ({ duration: reduceMotion() ? 0 : 600 });

// --- The map -------------------------------------------------------------------

// bottomInset is how much of the map's bottom edge something covers (the
// bottom sheet on phones), so a selected venue is kept clear of it.
// extraVenue ({ id, lat, lng }) can be selected though the filters leave it
// off the map; each new revealCount brings the selected venue back into view.
const MapView = ({
  mapStyle, venues, selectedVenueId, extraVenue, revealCount = 0, hoveredVenueId, bottomInset = 0, onSelectVenue, onViewChange
}) => {
  const containerRef = useRef(null);
  const [ map, setMap ] = useState(null);
  const [ failed, setFailed ] = useState(false);

  const markersRef = useRef(new Map()); // 'v<venue id>' or 'c<cluster id>' -> { marker, label }
  const dataRef = useRef(toGeoJSON([])); // what the source holds, for restyling
  const sentVenuesRef = useRef(null); // the venues last handed to the source
  const [ syncedVenues, setSyncedVenues ] = useState(null); // ...and once the markers show them
  const styleRef = useRef(mapStyle);

  const callbacks = useRef({});
  callbacks.current = { onSelectVenue, onViewChange };
  const highlightRef = useRef({});
  highlightRef.current = { selected: selectedVenueId, hovered: hoveredVenueId };

  // Create the map and its controls, once
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
    // "Near me": centres on you and shows where you are. It follows you until
    // you pan away; MapLibre only draws your dot while following.
    instance.addControl(new GeolocateControl({
      trackUserLocation: true,
      fitBoundsOptions: { maxZoom: NEAR_ME_ZOOM, ...motion() }
    }), 'top-right');
    instance.addControl(new ScaleControl(), 'bottom-left');

    // A new style drops the source, so put it back each time one loads
    instance.on('style.load', () => {
      addVenueSource(instance, dataRef.current);
      setMap(instance);
    });

    window.mapInstance = instance; // for system specs

    return () => {
      window.mapInstance = null;
      instance.remove();
    };
  }, []);

  // Follow the light/dark theme. A full reload, rather than a diff, so
  // style.load fires and the venue source goes back in.
  useEffect(() => {
    if (!map || styleRef.current === mapStyle) return;
    styleRef.current = mapStyle;
    map.setStyle(mapStyle, { diff: false });
  }, [ map, mapStyle ]);

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
      el.dataset.venueId = props.id;
      el.classList.toggle('is-selected', props.id === highlightRef.current.selected);
      el.classList.toggle('is-hovered', props.id === highlightRef.current.hovered);
      return new Marker({ element: el, anchor: 'bottom' });
    };

    const createClusterMarker = (props, lngLat) => {
      const el = markerButton('cluster-marker', async () => {
        const zoom = await map.getSource(SOURCE).getClusterExpansionZoom(props.cluster_id);
        map.easeTo({ center: lngLat, zoom, ...motion() });
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

        if (props.cluster) updateMarker(entry, clusterLabel(props), compactCount(props.gigs), clusterClasses(props));
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

  // Highlight the selected venue's marker, and the one hovered in the list
  useEffect(() => {
    markersRef.current.forEach((entry, key) => {
      if (!key.startsWith('v')) return;
      const el = entry.marker.getElement();
      el.classList.toggle('is-selected', key === `v${selectedVenueId}`);
      el.classList.toggle('is-hovered', key === `v${hoveredVenueId}`);
    });
  }, [ selectedVenueId, hoveredVenueId, syncedVenues ]);

  // Bring the selected venue into view, clear of the edges and the bottom sheet,
  // zooming in as far as it takes to split it out of any cluster
  const selectedVenue = venues.find(venue => venue.id === selectedVenueId) ||
    (extraVenue?.id === selectedVenueId ? extraVenue : undefined);
  const markersReady = syncedVenues === venues;
  const revealed = useRef({ id: null, inset: 0, count: 0 }); // once per selection (or sheet resize), not per filter change

  useEffect(() => {
    if (!selectedVenue) revealed.current.id = null;
    if (!map || !selectedVenue || !markersReady) return;

    const { id, lng, lat } = selectedVenue;
    if (revealed.current.id === id && revealed.current.inset === bottomInset && revealed.current.count === revealCount) return;
    const asked = revealed.current.count !== revealCount; // centre it, even if it's in view already
    revealed.current = { id, inset: bottomInset, count: revealCount };
    let cancelled = false;

    const isClear = () => {
      const { clientWidth: width, clientHeight: height } = map.getContainer();
      const point = map.project([ lng, lat ]);
      return inBounds(map.getBounds(), lat, lng) &&
        point.x > EDGE_MARGIN && point.x < width - EDGE_MARGIN &&
        point.y > EDGE_MARGIN && point.y < height - bottomInset - EDGE_MARGIN;
    };

    // The cluster holding the venue, if it's in one: check the nearest first
    const clusterHolding = async () => {
      const source = map.getSource(SOURCE);
      const target = map.project([ lng, lat ]);
      const clusters = map.querySourceFeatures(SOURCE, { filter: [ 'has', 'point_count' ] })
        .map(feature => ({ feature, distance: map.project(feature.geometry.coordinates).dist(target) }))
        .sort((a, b) => a.distance - b.distance)
        .slice(0, 5);

      for (const { feature } of clusters) {
        const leaves = await source.getClusterLeaves(feature.properties.cluster_id, Infinity, 0);
        if (leaves.some(leaf => leaf.properties.id === id)) return feature.properties.cluster_id;
      }
      return null;
    };

    const reveal = async (attempt = 0) => {
      if (cancelled) return;
      const clustered = !markersRef.current.has(`v${id}`) && await clusterHolding();
      if (cancelled) return;

      if (clustered !== null && clustered !== false && attempt < 4) {
        const zoom = await map.getSource(SOURCE).getClusterExpansionZoom(clustered);
        if (cancelled) return;
        map.once('idle', () => reveal(attempt + 1));
        map.easeTo({ center: [ lng, lat ], zoom, offset: [ 0, -bottomInset / 2 ], ...motion() });
      } else if (asked || !isClear()) {
        map.easeTo({ center: [ lng, lat ], offset: [ 0, -bottomInset / 2 ], ...motion() });
      }
    };

    reveal();
    return () => { cancelled = true; };
  }, [ map, selectedVenue?.id, markersReady, bottomInset, revealCount ]);

  if (failed) {
    return (
      <div className="flex size-full items-center justify-center p-6 text-center text-muted">
        This browser can’t draw the map (it needs WebGL).
      </div>
    );
  }

  return (
    <div ref={containerRef} className="size-full" role="region" aria-label="Map of venues"
      aria-busy={!map || syncedVenues !== venues} />
  );
};

export default MapView;
