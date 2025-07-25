import React, { useState, useCallback, useRef, useEffect } from 'react';
import MapView from './MapView';
import { normalizeLongitude, getFilterParamsFromUrl, updateFilterUrlParams } from '../fiddly-bits';
import Select from 'react-select';

const App = () => {
  const [gigs, setGigs] = useState([]);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const abortControllerRef = useRef(null);
  const lastBoundsRef = useRef(null);
  
  // Search filters state - initialize from URL parameters
  const [searchFilters, setSearchFilters] = useState(() => {
    // Get filter params from URL
    return getFilterParamsFromUrl();
  });
  
  // Acts data for the dropdown
  const [acts, setActs] = useState([]);
  const [loadingActs, setLoadingActs] = useState(false);
    
  // Track if this is the first page load
  const isFirstPageLoad = useRef(true);

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

  // Fetch acts for dropdown on component mount and initialize filters from URL
  useEffect(() => {
    // Get filter params from URL
    const urlFilterParams = getFilterParamsFromUrl();
    
    // Initialize search filters from URL parameters
    if (urlFilterParams) {
      setSearchFilters(prevFilters => ({
        ...prevFilters,
        startDate: urlFilterParams.startDate || '',
        endDate: urlFilterParams.endDate || '',
        // We'll set actIds after fetching the acts data
      }));
    }
    
    const fetchActs = async () => {
      setLoadingActs(true);
      try {
        const response = await fetch('/api/acts');
        if (!response.ok) throw new Error('Failed to fetch acts');
        const data = await response.json();
        
        // Format acts data for React Select with value/label format
        const formattedActs = data.map(act => ({
          value: act.id,
          label: act.name,
          image: act.primary_image_url || null
        }));

        const sortedActs = formattedActs.sort((a, b) => a.label.localeCompare(b.label));
        setActs(sortedActs);
        
        // Now that we have the acts data, we can set the selected acts from URL
        if (urlFilterParams && urlFilterParams.actIds && urlFilterParams.actIds.length > 0) {
          // The URL contains just the IDs, find the corresponding act objects
          const selectedActs = sortedActs.filter(act => 
            urlFilterParams.actIds.includes(act.value)
          );
          
          if (selectedActs.length > 0) {
            setSearchFilters(prevFilters => ({
              ...prevFilters,
              actIds: selectedActs // Store full act objects in component state
            }));
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

  // Function to fetch gigs based on bounds and filters
  const fetchGigsForBounds = useCallback(async (bounds, filters) => {
    if (!bounds) return;
    
    // Cancel any previous request
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    
    // Create new AbortController for this request
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
      
      // Add search filters to params if they exist
      if (filters.actIds && filters.actIds.length > 0) {
        // For multi-select, pass array of IDs
        const actIdValues = filters.actIds.map(act => act.value);
        
        // Add act IDs as an array parameter
        // Make sure we're not sending empty values
        if (actIdValues.length > 0 && actIdValues[0] !== '') {
          params.append('act_ids', actIdValues.join(','));
        }
      }

      // 

      if (filters.startDate) {
        params.append('start_date', filters.startDate);
      }
      
      if (filters.endDate) {
        params.append('end_date', filters.endDate);
      }
      
      const response = await fetch(`/api/gigs?${params}`, {
        signal: abortController.signal
      });
      if (!response.ok) throw new Error('Failed to fetch gigs');
      
      const data = await response.json();
      
      // Only update state if this request wasn't aborted
      if (!abortController.signal.aborted) {
        setGigs(data);
      }
    } catch (err) {
      // Don't show error if request was just aborted
      if (err.name !== 'AbortError') {
        console.error('Error fetching gigs:', err);
        setError('Loading failed; reattempt suckah');
      }
    } finally {
      // Only update loading state if this request wasn't aborted
      if (!abortController.signal.aborted) {
        setLoading(false);
      }
    }
  }, [setGigs, setError, setLoading]);

  // Handle map bounds changes
  const handleBoundsChange = useCallback((bounds) => {

    // Skip if bounds haven't changed significantly
    if (areBoundsSame(bounds, lastBoundsRef.current)) return;
    lastBoundsRef.current = bounds;
    
    console.log('isFirstPageLoad.current', isFirstPageLoad.current)
    // On first page load, ensure we're using the URL params
    if (isFirstPageLoad.current) {
      isFirstPageLoad.current = false;
      
      // Get filter params from URL to ensure we're using the latest URL state
      const urlFilterParams = getFilterParamsFromUrl();
      
      // For the initial load, we need to handle the actIds specially since they're just IDs in the URL
      // but we need the full act objects for the component state
      const filtersForApi = { ...searchFilters };
      
      // If URL has actIds but our state doesn't have the full objects yet (which happens on initial load)
      if (urlFilterParams.actIds && urlFilterParams.actIds.length > 0 && 
          (!searchFilters.actIds || searchFilters.actIds.length === 0)) {
        // Find the corresponding act objects from our acts array
        const selectedActs = acts.filter(act => urlFilterParams.actIds.includes(act.value));

        if (selectedActs.length > 0) {
          filtersForApi.actIds = selectedActs;
          
          // Also update the search filters state to reflect the URL params
          setSearchFilters(prev => ({
            ...prev,
            actIds: selectedActs
          }));
        }
      }
      
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
    if (lastBoundsRef.current) {
      fetchGigsForBounds(lastBoundsRef.current, newFilters);
    }
  }, [fetchGigsForBounds, searchFilters]);
  
  // Special handler for multi-select acts
  const handleActsChange = useCallback((selectedOptions) => {
    
    const selectedActs = selectedOptions || []; // Handle null when all options are cleared
    
    // Update component state with full act objects
    const newFilters = {
      ...searchFilters,
      actIds: selectedActs
    };
    setSearchFilters(newFilters);
    
    // Extract just the IDs for URL parameters
    const actIdsForUrl = selectedActs.map(act => act.value);

    // Update URL with just the IDs
    updateFilterUrlParams({
      ...newFilters,
      actIds: actIdsForUrl // Override with just IDs for URL
    });
    
    if (lastBoundsRef.current) {
      fetchGigsForBounds(lastBoundsRef.current, newFilters);
    }
  }, [fetchGigsForBounds, searchFilters]);
  
  // Clear all filters
  const handleClearFilters = useCallback(() => {
    const clearedFilters = { actIds: [], startDate: '', endDate: '' };
    setSearchFilters(clearedFilters);
    
    // Update URL with cleared filters using the granular utility function
    // This will only update the filter parameters without affecting map parameters
    updateFilterUrlParams(clearedFilters);
    
    if (lastBoundsRef.current) {
      fetchGigsForBounds(lastBoundsRef.current, clearedFilters);
    }
  }, [fetchGigsForBounds]);

  return (
    <div className="h-screen w-screen overflow-hidden flex flex-col bg-gray-100">
      <header className="bg-white shadow-sm top-0">
        <div className="w-full p-2 flex flex-wrap items-center gap-2">
          
          {/* Integrated Search Form */}
          <div className="flex flex-1 flex-wrap gap-2">

            {/* Act multi-select dropdown with thumbnails */}
            <div className="basis-full md:basis-auto flex-1">
              <div className="grow">
                <Select
                  name="acts"
                  isMulti
                  closeMenuOnSelect={false}
                  isLoading={loadingActs}
                  options={acts}
                  value={searchFilters.actIds}
                  onChange={handleActsChange}
                  placeholder="Show gigs performed by ..."
                  noOptionsMessage={() => "No acts found"}
                  classNamePrefix="react-select"
                  // Custom styles for the dropdown
                  styles={{
                    control: (baseStyles) => ({
                      ...baseStyles,
                      borderColor: '#d1d5db',
                      fontSize: '0.875rem'
                    }),
                    multiValue: (baseStyles) => ({
                      ...baseStyles,
                      backgroundColor: '#fff',
                      padding: '0px',
                      marginRight: '-2px',
                      borderRadius: '50%'
                    }),
                    multiValueLabel: (baseStyles) => ({
                      ...baseStyles,
                      // Hide the text label completely
                      padding: 0,
                      paddingLeft: 0
                    }),
                    multiValueRemove: (baseStyles) => ({
                      ...baseStyles,
                      zIndex: 9999,
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
                  // Custom components
                  components={{
                    // Custom MultiValueLabel to show only the image for selected values
                    MultiValueLabel: ({ data }) => (
                      <div className="w-8 h-8 rounded-full overflow-hidden">
                        <img 
                          src={data.image} 
                          alt={data.label} 
                          className="w-full h-full object-cover" 
                          title={data.label} // Show name on hover
                        />
                      </div>
                    )
                  }}
                  // Custom option component with image thumbnails (for dropdown options)
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
                className="flex-none py-1 px-3 h-10 text-sm border border-gray-300 rounded-md cursor-pointer hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-purple-500 shadow-sm"
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
