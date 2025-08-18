import React, { useState, useCallback, useRef, useEffect, useMemo } from 'react';
import MapView from './MapView';
import { normalizeLongitude, getFilterParamsFromUrl, updateFilterUrlParams } from '../fiddly-bits';
import Select from 'react-select';

const App = () => {

  const abortControllerRef = useRef(null);
  const lastBoundsRef      = useRef(null);
  const isFirstPageLoad    = useRef(true); // Track if this is the first page load

  const [gigs, setGigs]                   = useState([]);
  const [error, setError]                 = useState(null);
  const [loading, setLoading]             = useState(false);
  const [acts, setActs]                   = useState([]); // Acts data for the dropdown
  const [loadingActs, setLoadingActs]     = useState(false);
  const [searchFilters, setSearchFilters] = useState(() => getFilterParamsFromUrl()); // Search filters: init from URL params

  // Helper to compare bounds with special handling for antimeridian crossing
  const areBoundsSame = (bounds1, bounds2) => {
    if (!bounds1 || !bounds2) return false;
    const precision = 4; // 4 decimal places
    
    const round = (num) => Math.round(num * Math.pow(10, precision)) / Math.pow(10, precision);
    
    // Normalize east/west for comparison to handle antimeridian crossing
    const east1 = normalizeLongitude(bounds1.getEast());
    const west1 = normalizeLongitude(bounds1.getWest());
    const east2 = normalizeLongitude(bounds2.getEast());
    const west2 = normalizeLongitude(bounds2.getWest());
    
    // Special case for bounds that cross the antimeridian
    const crossesAntimeridian1 = west1 > east1;
    const crossesAntimeridian2 = west2 > east2;
    
    // If one crosses and the other doesn't, they're definitely different
    if (crossesAntimeridian1 !== crossesAntimeridian2) return false;
    
    return round(bounds1.getNorth()) === round(bounds2.getNorth()) &&
           round(bounds1.getSouth()) === round(bounds2.getSouth()) &&
           round(east1) === round(east2) &&
           round(west1) === round(west2);
  };

  useEffect(() => {
    const fetchActs = async () => {
      setLoadingActs(true);

      try {
        const response = await fetch('/api/acts');
        if (!response.ok) throw new Error('Failed to fetch acts');
        
        const data = await response.json();
        
        const sortedActs = data.map(act => ({
          value: act.id,
          label: act.name,
          image: act.primary_image_url
        })).sort((a, b) => a.label.localeCompare(b.label));
        
        setActs(sortedActs);
        const urlFilterParams = getFilterParamsFromUrl();
        // Now that we have the acts data, we can set the selected acts from URL
        if (urlFilterParams && urlFilterParams.actIds && urlFilterParams.actIds.length > 0) {
          // The URL contains just the IDs, find the corresponding act objects
          const selectedActs = sortedActs.filter(act => 
            urlFilterParams.actIds.includes(act.value)
          );

          if (selectedActs.length > 0) {
            const newFilters = {
              ...urlFilterParams,
              acts: selectedActs // Store full act objects in component state
            };
            setSearchFilters(newFilters);
            
            // If we have map bounds and this is still the first page load, make the API call now
            if (lastBoundsRef.current && isFirstPageLoad.current) {
              isFirstPageLoad.current = false;
              // Use the newFilters which contain the full act objects
              fetchGigsForBounds(lastBoundsRef.current, newFilters);
            }
          }
        }
      } catch (err) {
        console.error('Error fetching acts:', err);
      } finally {
        setLoadingActs(false);
      }
    };
    
    fetchActs();
  }, []);

  const fetchGigsForBounds = useCallback(async (bounds, filters) => {
    if (!bounds) return;
    
    if (abortControllerRef.current) abortControllerRef.current.abort();
    
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    
    setError(null);
    setLoading(true);
    
    try {
      const params = new URLSearchParams({
        north: bounds.getNorth(),
        south: bounds.getSouth(),
        east: normalizeLongitude(bounds.getEast()),
        west: normalizeLongitude(bounds.getWest())
      });

      if (filters.actIds && filters.actIds.length > 0)
        params.append('act_ids', filters.actIds.join(','));

      if (filters.startDate) params.append('start_date', filters.startDate);
      if (filters.endDate)   params.append('end_date', filters.endDate);
      
      const response = await fetch(`/api/gigs?${params}`, { signal: abortController.signal });
      if (!response.ok) throw new Error('Failed to fetch gigs');
      
      const data = await response.json();
      
      // Only update state if this request wasn't aborted
      if (!abortController.signal.aborted) setGigs(data);

    } catch (err) {
      // Don't show error if request was just aborted
      if (err.name !== 'AbortError') {
        console.error('Error fetching gigs:', err);
        setError('Loading failed; reattempt suckah');
      }
    } finally {
      // Only update loading state if this request wasn't aborted
      if (!abortController.signal.aborted) setLoading(false);
    }
  }, [setGigs, setError, setLoading]);

    
  // Trigger API call when acts are loaded and we have URL act IDs to process
  useEffect(() => {
    if (!acts.length || !isFirstPageLoad.current) return; // No acts; first page-load? Exit.

    const urlFilterParams = getFilterParamsFromUrl();
    if (!urlFilterParams.actIds) return;

    const selectedActs = acts.filter(act => urlFilterParams.actIds.includes(act.value));    
    if (!selectedActs.length) return;

    // Create filters with the act objects
    const filtersWithActs = {
      ...urlFilterParams,
      acts: selectedActs
    };
    
    // Update search filters state
    setSearchFilters(filtersWithActs);
    
    // Make the API call with the correct filters
    isFirstPageLoad.current = false;
    fetchGigsForBounds(lastBoundsRef.current, filtersWithActs);
    
  }, [acts, fetchGigsForBounds]);


  // Fires on each change - and once on app load.
  const handleBoundsChange = useCallback((bounds) => {
    if (areBoundsSame(bounds, lastBoundsRef.current)) return;

    lastBoundsRef.current = bounds;
    
    if (isFirstPageLoad.current) {
      const urlFilterParams = getFilterParamsFromUrl();
      
      // For the initial load, we need to handle the actIds specially since they're just IDs in the URL
      // but we need the full act objects for the component state
      const filtersForApi = { ...searchFilters };
      
      // If URL has actIds but our state doesn't have the full objects yet (which happens on initial load)
      if (urlFilterParams.actIds && urlFilterParams.actIds.length > 0 && 
          (!searchFilters.actIds || searchFilters.actIds.length === 0)) {
        
        if (!acts.length) return;
        
        // Find the corresponding act objects from our acts array
        const selectedActs = acts.filter(act => urlFilterParams.actIds.includes(act.value));

        if (selectedActs.length > 0) {
          // Set the act objects in the API filters
          filtersForApi.actIds = selectedActs;
          
          // Also update the search filters state to reflect the URL params
          setSearchFilters(prev => ({
            ...prev,
            startDate: urlFilterParams.startDate || prev.startDate,
            endDate: urlFilterParams.endDate || prev.endDate,
            actIds: selectedActs.map(act => act.value)
          }));
        }
      }
      
      if (urlFilterParams.startDate) filtersForApi.startDate = urlFilterParams.startDate;
      if (urlFilterParams.endDate)   filtersForApi.endDate = urlFilterParams.endDate;
      
      // Now we're actually making the API call, so set the flag
      isFirstPageLoad.current = false;

      // Fetch gigs with URL filters
      fetchGigsForBounds(bounds, filtersForApi);

    } else {
      // For subsequent bounds changes, use the current filters from component state
      fetchGigsForBounds(bounds, searchFilters);
    }
  }, [fetchGigsForBounds, searchFilters, acts]);

  // Handle search filter changes
  const handleFilterChange = useCallback((name, value) => {

    // Update the filter state
    const newFilters = {
      ...searchFilters,
      [name]: value
    };

    // Set the new filters
    setSearchFilters(newFilters);
    
    // Update URL with new filters using the granular utility function
    // This will only update the filter parameters without affecting map parameters
    updateFilterUrlParams(newFilters);
    
    // Trigger an API call with the new filters
    if (lastBoundsRef.current) fetchGigsForBounds(lastBoundsRef.current, newFilters);

  }, [fetchGigsForBounds, searchFilters]);
  
  // Special handler for multi-select acts
  const handleActsChange = useCallback((selectedOptions) => {
    const selectedActs = selectedOptions || []; // Handle null when all options are cleared
    
    // Extract just the IDs for URL parameters
    const actIds = selectedActs.map(act => act.value);

    // Update component state with full act objects
    const newFilters = {
      ...searchFilters,
      acts: selectedActs,
      actIds: actIds
    };
    setSearchFilters(newFilters);
 
    // Update URL with just the IDs
    updateFilterUrlParams({
      ...newFilters,
     // actIds: actIds // Override with just IDs for URL
    });
    
    if (lastBoundsRef.current) fetchGigsForBounds(lastBoundsRef.current, newFilters);

  }, [fetchGigsForBounds, searchFilters]);
  
  // Clear all filters
  const handleClearFilters = useCallback(() => {

    const clearedFilters = { actIds: [], startDate: '', endDate: '' };
    setSearchFilters(clearedFilters);
    updateFilterUrlParams(clearedFilters);
    if (lastBoundsRef.current) fetchGigsForBounds(lastBoundsRef.current, clearedFilters);

  }, [fetchGigsForBounds]);

  return (
    <div className="h-screen w-screen overflow-hidden flex flex-col bg-gray-100">
      <header className="bg-white shadow-sm top-0">
        <div className="w-full p-2 flex flex-wrap items-center gap-2">
          
          {/* Integrated Search Form */}
          <div className="flex flex-1 flex-wrap gap-2">

            {/* Act multi-select dropdown with thumbnails */}
            <div id="acts" className="basis-full md:basis-auto flex-1 relative">
              <Select
                name="acts"
                isMulti
                closeMenuOnSelect={false}
                isLoading={loadingActs}
                options={acts}
                value={searchFilters.acts}
                onChange={handleActsChange}
                placeholder="Show gigs performed by ..."
                noOptionsMessage={() => "No acts found"}
                classNamePrefix="react-select"
                styles={{
                  control: (baseStyles) => ({
                    ...baseStyles,
                    paddingLeft: '6px',
                    borderColor: '#d1d5db',
                    fontSize: '0.875rem',
                    minHeight: '40px',
                    height: 'auto',
                    flexWrap: 'nowrap'
                  }),
                  valueContainer: (baseStyles) => ({
                    ...baseStyles,
                    padding: '2px 8px',
                    flexWrap: 'nowrap',
                    overflow: 'hidden',
                    position: 'relative'
                  }),
                  multiValue: (baseStyles, { index }) => {
                    const acts = document.getElementById('acts');
                    // 73px for the remove/select-acts buttons, 52px for act thumbs
                    const maxVisibleCount = Math.floor((acts.offsetWidth - 73) / 53); 
                    return {
                      ...baseStyles,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      backgroundColor: '#fff',
                      marginLeft: '5px',
                      marginRight: '-5px',
                      borderRadius: '50%',
                      flexShrink: 0,
                      display: (index < maxVisibleCount-2 ? 'flex' : 'none')
                    };
                  },
                  multiValueLabel: (baseStyles) => ({
                    ...baseStyles,
                    padding: 0,
                    paddingLeft: 0
                  }),
                  multiValueRemove: (baseStyles) => ({
                    ...baseStyles,
                    zIndex: 10,
                    cursor: 'pointer',
                    borderRadius: '50%',
                    position: 'relative',
                    top: 0,
                    right: 10,
                    width: '20px',
                    height: '20px',
                    backgroundColor: '#aaa',
                    '&:hover': {
                      backgroundColor: 'rgba(220,38,38,1)',
                      color: 'white'
                    }
                  }),
                  menu: (baseStyles) => ({
                    ...baseStyles
                  })
                }}
                components={{
                  MultiValueLabel: ({ data }) => (
                    <div className="w-8 h-8 rounded-full overflow-hidden">
                      <img 
                        src={data.image} 
                        alt={data.label} 
                        className="w-full h-full object-cover" 
                        title={data.label} // Show name on hover
                      />
                    </div>
                  ),
                  ValueContainer: ({ children, getValue, ...props }) => {
                    const acts = document.getElementById('acts');
                    let hiddenCount = 0;

                    if (acts) {
                      const maxVisibleCount = Math.floor((acts.offsetWidth - 73) / 53); 
                      hiddenCount = Math.max(getValue().length - maxVisibleCount, 0);
                    }

                    return (
                      <div id="acts_select_container" className="flex items-center flex-1 overflow-hidden">
                        <div className="flex items-center flex-wrap">
                          {children}
                        </div>
                        {hiddenCount > 0 && (
                          <div className="-ml-1 px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded-full flex-shrink-0">
                            +{hiddenCount} more
                          </div>
                        )}
                      </div>
                    );
                  },
                }}
                formatOptionLabel={(option, { context }) => {
                  // Only show the full option with text in the menu, not in the value container
                  if (context === 'menu') {
                    return (
                      <div className="flex items-center gap-2">
                        <img src={option.image} alt={option.label} className="w-8 h-8 rounded-full object-cover" />
                        <span className="text-sm">{option.label}</span>
                      </div>
                    );
                  }
                  // For the value container, we'll use the custom MultiValueLabel component
                  return null;
                }}
              />
            </div>

            {/* Start date */}
            <div className="basis-full xs:flex-1 md:flex-none flex flex-row items-center items-stretch h-10 shadow-sm rounded-md">
              <label 
                htmlFor="start_date"
                className="text-sm text-gray-600 border border-gray-300 bg-gray-100 border-r-0 rounded-l-md p-1 px-2 flex items-center cursor-pointer"
              >
                From
              </label>
              <input
                type="date"
                id="start_date"
                name="start_date"
                className="grow xs:w-24 sm:w-auto py-1 px-2 border border-gray-300 rounded-r-md text-sm cursor-pointer hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-purple-500"
                value={searchFilters.startDate}
                onChange={(e) => handleFilterChange('startDate', e.target.value)}
                onClick={(e) => e.target.showPicker?.()}
                placeholder="Start Date"
                style={{ colorScheme: 'light' }}
              />
            </div>
            
            {/* End date */}
            <div className="basis-full xs:flex-1 md:flex-none flex flex-row items-center items-stretch h-10 shadow-sm rounded-md">
              <label 
                htmlFor="end_date"
                className="text-sm text-gray-600 border border-gray-300 bg-gray-100 border-r-0 rounded-l-md p-1 px-2 flex items-center cursor-pointer"
              >
                To
              </label>
              <input
                type="date"
                id="end_date"
                name="end_date"
                className="grow xs:w-24 sm:w-auto py-1 px-2 border border-gray-300 rounded-r-md text-sm cursor-pointer hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-purple-500"
                value={searchFilters.endDate}
                onChange={(e) => handleFilterChange('endDate', e.target.value)}
                onClick={(e) => e.target.showPicker?.()}
                placeholder="End Date"
                style={{ colorScheme: 'light' }}
              />
            </div>

          </div>
          
          <div className="flex flex-col md:flex-row gap-2 items-center">
            {/* Clear filters button */}
            <button
                onClick={handleClearFilters}
                className="flex-none py-0 px-3 h-10 text-sm border border-gray-300 rounded-md cursor-pointer hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-purple-500 shadow-sm"
              >
                Clear
            </button>

            <div className="w-16 h-10 flex justify-center items-center">
              {loading ? (
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-purple-600"></div>
              ) : error ? (
                <span className="text-sm text-red-600">{error}</span>
              ) : (
                <span className="text-sm text-gray-600 text-center">{gigs.length} gigs</span>
              )}
            </div>

          </div>
        </div>
      </header>

      <main className="flex-1 relative overflow-y-auto">
        <div className="h-full w-full">
          <MapView gigs={gigs} onBoundsChange={handleBoundsChange} />
        </div>
      </main>
    </div>
  );
};

export default App;
