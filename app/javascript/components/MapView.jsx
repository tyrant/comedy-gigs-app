import React, { useMemo, useEffect, useCallback, useRef, useState } from 'react';
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
  const markersRef = useRef({});
  const popupStatesRef = useRef({});
  const markerClusterRef = useRef(null);
  
  // Create popup content for a venue
  const createPopupContent = useCallback((venue, gigs) => {
    // Create a container for the popup content
    const container = document.createElement('div');
    container.className = 'venue-popup w-full sm:w-[330px] relative';
    
    // Create the venue image if available
    if (venue.primary_image_url) {
      const imageContainer = document.createElement('div');
      imageContainer.className = 'w-full h-40 overflow-hidden';
      
      const image = document.createElement('img');
      image.src = venue.primary_image_url;
      image.alt = venue.name;
      image.className = 'w-full h-full object-cover';
      
      imageContainer.appendChild(image);
      container.appendChild(imageContainer);
    }
    
    // Create the content container
    const contentContainer = document.createElement('div');
    contentContainer.className = 'mt-2 max-h-[420px] overflow-y-auto scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100';
    
    // Create the sticky header
    const headerContainer = document.createElement('div');
    headerContainer.className = 'sticky top-0 z-10 bg-white px-2 pt-2 pb-3 backdrop-blur-sm bg-opacity-90';
    
    const venueTitle = document.createElement('h3');
    venueTitle.className = 'text-lg sm:text-xl font-bold leading-tight';
    venueTitle.textContent = venue.name;
    
    const venueLocation = document.createElement('p');
    venueLocation.className = 'text-sm sm:text-base text-gray-600 mt-1';
    venueLocation.textContent = `${venue.city}, ${venue.country}`;
    
    const gradient = document.createElement('div');
    gradient.className = 'absolute left-0 right-0 bottom-0 h-4 bg-gradient-to-b from-white to-transparent';
    
    headerContainer.appendChild(venueTitle);
    headerContainer.appendChild(venueLocation);
    headerContainer.appendChild(gradient);
    
    // Create the gigs list
    const gigsList = document.createElement('div');
    gigsList.className = 'space-y-4 pr-2';
    
    gigs.forEach(gig => {
      const gigItem = document.createElement('div');
      gigItem.className = 'border-t py-3 first:border-t-0 first:pt-0 hover:bg-gray-50 px-2';
      
      const gigTitle = document.createElement('h4');
      gigTitle.className = 'font-semibold text-gray-900';
      gigTitle.textContent = gig.name;
      
      const gigDate = document.createElement('p');
      gigDate.className = 'text-gray-600 text-sm';
      gigDate.textContent = formatDate(gig.start_time);
      
      gigItem.appendChild(gigTitle);
      gigItem.appendChild(gigDate);
      
      // Add acts if available
      if (gig.acts && gig.acts.length > 0) {
        const actsContainer = document.createElement('div');
        actsContainer.className = 'mt-2';
        
        const actsLabel = document.createElement('p');
        actsLabel.className = 'text-xs text-gray-500 mb-1';
        actsLabel.textContent = 'Featuring:';
        
        const actsWrapper = document.createElement('div');
        actsWrapper.className = 'flex flex-wrap gap-2';
        
        gig.acts.forEach(act => {
          const actItem = document.createElement('div');
          actItem.className = 'flex items-center bg-purple-50 rounded-md p-1';
          
          if (act.primary_image_url) {
            const actImageContainer = document.createElement('div');
            actImageContainer.className = 'w-8 h-8 rounded-full overflow-hidden mr-1';
            
            const actImage = document.createElement('img');
            actImage.src = act.primary_image_url;
            actImage.alt = act.name;
            actImage.className = 'w-full h-full object-cover';
            
            actImageContainer.appendChild(actImage);
            actItem.appendChild(actImageContainer);
          }
          
          const actName = document.createElement('span');
          actName.className = 'text-xs text-purple-800 font-medium';
          actName.textContent = act.name;
          
          actItem.appendChild(actName);
          actsWrapper.appendChild(actItem);
        });
        
        actsContainer.appendChild(actsLabel);
        actsContainer.appendChild(actsWrapper);
        gigItem.appendChild(actsContainer);
      }
      
      // Add ticket link if available
      if (gig.ticket_url) {
        const ticketLink = document.createElement('a');
        ticketLink.href = gig.ticket_url;
        ticketLink.target = '_blank';
        ticketLink.rel = 'noopener noreferrer';
        ticketLink.className = 'mt-2 inline-block px-3 py-1 text-sm font-medium text-white bg-purple-600 rounded hover:bg-purple-700';
        ticketLink.textContent = 'Get Tickets';
        
        gigItem.appendChild(ticketLink);
      }
      
      gigsList.appendChild(gigItem);
    });
    
    contentContainer.appendChild(headerContainer);
    contentContainer.appendChild(gigsList);
    container.appendChild(contentContainer);
    
    return container;
  }, []);
  
  // Initialize marker cluster group
  useEffect(() => {
    // Create marker cluster group if it doesn't exist
    if (!markerClusterRef.current && map) {
      markerClusterRef.current = L.markerClusterGroup({
        chunkedLoading: true,
        maxClusterRadius: 40,
        spiderfyOnMaxZoom: true,
        showCoverageOnHover: true,
        zoomToBoundsOnClick: true
      });
      
      // Add the cluster group to the map
      map.addLayer(markerClusterRef.current);
    }
    
    // Cleanup on unmount
    return () => {
      if (markerClusterRef.current && map) {
        map.removeLayer(markerClusterRef.current);
        markerClusterRef.current = null;
      }
    };
  }, [map]);
  
  // Effect to create and manage markers
  useEffect(() => {
    if (!markerClusterRef.current || !map) return;
    
    // Track current markers to remove stale ones
    const currentMarkerIds = new Set();
    
    // Create or update markers for each venue
    venueGroups.forEach(({ venue, gigs }) => {
      const venueId = venue.id;
      currentMarkerIds.add(venueId.toString());
      
      const lat = parseFloat(venue.latitude);
      const lng = parseFloat(venue.longitude);
      
      // Skip invalid coordinates
      if (isNaN(lat) || isNaN(lng)) {
        console.warn(`Invalid coordinates for venue ${venue.name}:`, venue);
        return;
      }
      
      // If marker already exists, just update its position if needed
      if (markersRef.current[venueId]) {
        const marker = markersRef.current[venueId];
        const currentPos = marker.getLatLng();
        
        if (currentPos.lat !== lat || currentPos.lng !== lng) {
          marker.setLatLng([lat, lng]);
        }
        
        // Check if popup was open before and reopen it
        if (popupStatesRef.current[venueId]) {
          setTimeout(() => marker.openPopup(), 100); // Small delay to ensure proper rendering
        }
      } else {
        // Create new marker
        const marker = L.marker([lat, lng], { icon: comedyIcon });
        
        // Create popup with content
        const popupContent = createPopupContent(venue, gigs);
        const popup = L.popup({
          maxWidth: 350,
          maxHeight: 500,
          className: 'venue-popup',
          autoClose: false,  // Important: prevent auto-closing on map click
          closeOnClick: false  // Important: prevent closing when clicking elsewhere
        }).setContent(popupContent);
        
        // Bind popup to marker
        marker.bindPopup(popup);
        
        // Track popup open state
        marker.on('popupopen', () => {
          popupStatesRef.current[venueId] = true;
        });
        
        marker.on('popupclose', () => {
          popupStatesRef.current[venueId] = false;
        });
        
        // Add to cluster group and store reference
        markerClusterRef.current.addLayer(marker);
        markersRef.current[venueId] = marker;
      }
    });
    
    // Remove stale markers
    Object.keys(markersRef.current).forEach(id => {
      if (!currentMarkerIds.has(id)) {
        markerClusterRef.current.removeLayer(markersRef.current[id]);
        delete markersRef.current[id];
        delete popupStatesRef.current[id];
      }
    });
    
    // Cleanup on unmount is handled by the cluster group effect
  }, [map, venueGroups, createPopupContent]);
  
  // This component doesn't render anything directly
  // All markers are managed via the Leaflet API
  return null;
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
