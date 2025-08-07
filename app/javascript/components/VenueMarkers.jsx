import React, { useEffect, useRef, useCallback } from 'react';
import { useMap } from 'react-leaflet';
import { createRoot } from 'react-dom/client';
import { formatDate, getMapParamsFromUrl, updateMapUrlParams, updateVenueUrlParam } from '../fiddly-bits';
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

  // Group this popup's Gigs by Act: 
  // [ ..., { acts: [...], gigs: [...]}, ... ]
  const gigsGroupedByActs = [];

  gigs.forEach(gig => {
    const existingActs = gigsGroupedByActs.find(group => {
      const groupActIds = group.acts.map(a => a.id);
      const gigActIds = gig.acts.map(a => a.id);

      return groupActIds.every((id, i) => id == gigActIds[i]);
    });

    if (!existingActs) gigsGroupedByActs.push({ acts: gig.acts, gigs: [gig] });
    else              existingActs.gigs.push(gig);
  });

  return (
    <div className="venue-popup w-[280px] sm:w-[330px] bg-white rounded-md overflow-hidden shadow-lg">
      {venue.primary_image_url && (
        <div className="relative">
          <div className="w-full h-40 overflow-hidden">
            <img 
              src={venue.primary_image_url} 
              alt={venue.name} 
              className="w-full h-full object-cover" 
            />
          </div>

          <div className="absolute bottom-0 p-2 z-10 w-full h-4/5 bg-gradient-to-b from-transparent to-gray-900">
            <div className="absolute bottom-0 p-2">
              <h3 className="text-lg font-bold leading-5 text-gray-100">
                {venue.name}
              </h3>
              <div className="flex items-center mt-0.5">
                <span className="text-gray-200 text-xs truncate">
                  {venue.address || venue.city || ''}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}
      
      <div className="max-h-[220px] overflow-y-auto scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100">

 
        
        <div className="divide-y divide-gray-100 px-3 py-2">
          {gigsGroupedByActs.map(group => (

            <>
              <div key={group.acts.map(act => act.id).join('-')}>
                {group.acts && group.acts.length > 0 && (
                  <div className="mt-1.5">
                    <div className="flex flex-wrap gap-1.5">
                      {group.acts.map(act => (
                        <div key={act.id} data-act-id={act.id} className="inline-flex items-center bg-purple-50 rounded-full py-0.5 px-2">
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

              <div>
                {group.gigs && group.gigs.length > 0 && (
                  <div>
                    {group.gigs.map(gig => (
                      <div key={gig.id} data-gig-id={gig.id} className="py-2.5 first:pt-0 last:pb-0 px-2 hover:bg-gray-50 transition-colors duration-150 rounded">
                        <div className="flex justify-between items-start">
                          <div className="flex-1 min-w-0">
                            <h4 className="font-medium text-gray-900 text-xs truncate">
                              {gig.name}
                            </h4>
                            <span className="text-gray-500 text-xs">
                              {formatDate(gig.start_time)}
                            </span>
                          </div>
                          
                          {gig.ticket_url && (
                            <a 
                              href={gig.ticket_url}
                              data-role="ticket-url"
                              target="_blank" 
                              rel="noopener noreferrer"
                              className="ml-2 shrink-0 px-2.5 py-1 text-xs font-medium text-white bg-purple-600 rounded hover:bg-purple-700 transition-colors duration-150"
                            >
                              Tickets
                            </a>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </>
          ))}

        </div>
      </div>
    </div>
  );
};

// Venue markers component
const VenueMarkers = ({ venueGroups }) => {
  const map              = useMap();
  const markersRef       = useRef({});
  const popupStatesRef   = useRef({});
  const markerClusterRef = useRef(null);
  
  const createPopupContent = useCallback((venue, gigs) => {
    const container = document.createElement('div');
    const root = createRoot(container);
    root.render(<PopupContent venue={venue} gigs={gigs} />);
    return container;
  }, []);
  
  useEffect(() => {
    if (!map || markerClusterRef.current) return;

    markerClusterRef.current = L.markerClusterGroup({
      chunkedLoading: true,
      maxClusterRadius: 50,
      spiderfyOnMaxZoom: true,
      showCoverageOnHover: true,
      zoomToBoundsOnClick: true
    });
    
    map.addLayer(markerClusterRef.current);

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
      
      // If marker already exists, update its position and popup content
      if (markersRef.current[venueId]) {
        const marker = markersRef.current[venueId];
        const currentPos = marker.getLatLng();
        
        if (currentPos.lat !== lat || currentPos.lng !== lng)
          marker.setLatLng([lat, lng]);
        
        // Only update popup if it's not currently open to prevent duplication
        if (!marker.isPopupOpen()) {
          // Unbind existing popup before creating new one
          marker.unbindPopup();
          
          // Always update popup content with new gig data
          const popupContent = createPopupContent(venue, gigs);
          const popup = L.popup({
            autoClose: false,
            closeOnClick: true,
            className: 'venue-popup-container',
            maxWidth: 340,
            minWidth: 280,
            offset: [0, -5],
            closeButton: true
          }).setContent(popupContent);
          
          marker.bindPopup(popup);
          
          // Check if popup was open before and reopen it
          if (popupStatesRef.current[venueId])
            setTimeout(() => marker.openPopup(), 100); // Small delay to ensure proper rendering
        }

      } else {
        // Create new marker
        const marker = L.marker([lat, lng], { 
          icon: comedyIcon,
          title: venue.name
        });
        
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
          
          // Update URL with venue ID and map position
          const mapCenter = map.getCenter();
          const mapZoom = map.getZoom();
          
          // Update map parameters
          updateMapUrlParams(mapCenter.lat, mapCenter.lng, mapZoom);
          
          // Update venue parameter
          updateVenueUrlParam(venueId);
        });
        
        marker.on('popupclose', () => {
          popupStatesRef.current[venueId] = false;
          
          // Remove venue ID from URL but preserve map position
          const mapCenter = map.getCenter();
          const mapZoom = map.getZoom();
          
          // Update map parameters
          updateMapUrlParams(mapCenter.lat, mapCenter.lng, mapZoom);
          
          // Remove venue parameter
          updateVenueUrlParam(null);
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
