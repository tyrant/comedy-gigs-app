import React, { useEffect, useRef, useCallback } from 'react';
import { useMap } from 'react-leaflet';
import { createRoot } from 'react-dom/client';
import { formatDate, getMapParamsFromUrl, updateUrlParams } from '../fiddly-bits';
import L from 'leaflet'
import 'leaflet.markercluster'

// Custom comedy marker icon
const comedyIcon = L.icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-violet.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

// Popup content component
const PopupContent = ({ venue, gigs }) => {
  return (
    <div className="venue-popup w-[280px] sm:w-[330px] relative bg-white rounded-md overflow-hidden shadow-lg">
      {venue.primary_image_url && (
        <div className="w-full h-40 overflow-hidden">
          <img 
            src={venue.primary_image_url} 
            alt={venue.name} 
            className="w-full h-full object-cover" 
          />
        </div>
      )}
      
      <div className="max-h-[420px] overflow-y-auto scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100">
        {/* Sticky header */}
        <div className="sticky top-0 z-10 bg-white px-2 pt-2 pb-2 backdrop-blur-sm bg-opacity-95 border-b border-gray-100">
          <h3 className="text-base sm:text-lg font-bold leading-tight text-gray-900">
            {venue.name}
          </h3>
          <div className="flex items-center mt-0.5">
            <span className="text-gray-400 mr-1 text-xs">📍</span>
            <p className="text-gray-500 text-xs sm:text-sm truncate">
              {venue.address || venue.city || ''}
            </p>
          </div>
          <div className="absolute bottom-0 left-0 right-0 h-3 bg-gradient-to-t from-white to-transparent pointer-events-none"></div>
        </div>
        
        {/* Gigs list */}
        <div className="divide-y divide-gray-100 px-3 py-2">
          {gigs.map(gig => (
            <div key={gig.id} className="py-2.5 first:pt-0 last:pb-0 px-2 hover:bg-gray-50 transition-colors duration-150 rounded">
              {/* Gig header with title and ticket button */}
              <div className="flex justify-between items-start">
                <div className="flex-1 min-w-0">
                  <h4 className="font-medium text-gray-900 text-sm sm:text-base truncate">
                    {gig.name}
                  </h4>
                  <p className="text-gray-500 text-xs sm:text-sm">
                    {formatDate(gig.start_time)}
                  </p>
                </div>
                
                {gig.ticket_url && (
                  <a 
                    href={gig.ticket_url} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="ml-2 shrink-0 px-2.5 py-1 text-xs font-medium text-white bg-purple-600 rounded hover:bg-purple-700 transition-colors duration-150"
                  >
                    Tickets
                  </a>
                )}
              </div>
              
              {/* Acts list */}
              {gig.acts && gig.acts.length > 0 && (
                <div className="mt-1.5">
                  <div className="flex flex-wrap gap-1.5">
                    <span className="text-xs text-gray-400 mr-1">With:</span>
                    {gig.acts.map(act => (
                      <div key={act.id} className="inline-flex items-center bg-purple-50 rounded-full py-0.5 px-2">
                        {act.primary_image_url && (
                          <div className="w-4 h-4 rounded-full overflow-hidden mr-1 flex-shrink-0">
                            <img 
                              src={act.primary_image_url} 
                              alt={act.name} 
                              className="w-full h-full object-cover" 
                            />
                          </div>
                        )}
                        <span className="text-xs text-purple-800 font-medium truncate max-w-[100px]">
                          {act.name}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// Venue markers component
const VenueMarkers = ({ venueGroups }) => {
  const map = useMap();
  const markersRef = useRef({});
  const popupStatesRef = useRef({});
  const markerClusterRef = useRef(null);
  
  // Create popup content using React and ReactDOM
  const createPopupContent = useCallback((venue, gigs) => {
    const container = document.createElement('div');
    const root = createRoot(container);
    root.render(<PopupContent venue={venue} gigs={gigs} />);
    return container;
  }, []);
  
  // Initialize marker cluster group
  useEffect(() => {
    if (!markerClusterRef.current && map) {
      // Check if L.markerClusterGroup is available
      if (typeof L.markerClusterGroup !== 'function') {
        console.error('L.markerClusterGroup is not a function. Make sure leaflet.markercluster is properly loaded.');
        // Fallback to regular layer group if markerClusterGroup is not available
        markerClusterRef.current = L.layerGroup();
      } else {
        markerClusterRef.current = L.markerClusterGroup({
          chunkedLoading: true,
          maxClusterRadius: 40,
          spiderfyOnMaxZoom: true,
          showCoverageOnHover: true,
          zoomToBoundsOnClick: true
        });
      }
      
      map.addLayer(markerClusterRef.current);
    }
    
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
          autoClose: false,
          closeOnClick: true,
          className: 'venue-popup-container',
          maxWidth: 340,
          minWidth: 280,
          offset: [0, -5],
          autoPanPadding: [20, 20]
        }).setContent(popupContent);
        
        // Bind popup to marker
        marker.bindPopup(popup);
        
        // Track popup open state and update URL
        marker.on('popupopen', () => {
          popupStatesRef.current[venueId] = true;
          console.log('Popup gigs:', gigs);
          // Update URL with venue ID
          const mapCenter = map.getCenter();
          const mapZoom = map.getZoom();
          updateUrlParams(mapCenter.lat, mapCenter.lng, mapZoom, venueId);
        });
        
        marker.on('popupclose', () => {
          popupStatesRef.current[venueId] = false;
          
          // Remove venue ID from URL
          const mapCenter = map.getCenter();
          const mapZoom = map.getZoom();
          updateUrlParams(mapCenter.lat, mapCenter.lng, mapZoom);
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
    
    // Check for venue ID in URL and open the corresponding popup after all markers are created
    const { venueId } = getMapParamsFromUrl();
    if (venueId && markersRef.current[venueId]) {
      setTimeout(() => {
        markersRef.current[venueId].openPopup();
        popupStatesRef.current[venueId] = true;
      }, 300); // Small delay to ensure proper rendering
    }
  }, [map, venueGroups, createPopupContent]);
  
  return null;
};

export default VenueMarkers;
