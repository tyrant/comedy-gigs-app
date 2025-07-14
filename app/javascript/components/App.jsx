import React, { useState, useCallback, useRef, useEffect } from 'react';
import MapView from './MapView';
import { normalizeLongitude } from '../fiddly-bits';
import Select from 'react-select';

// Debug flag to log API calls
const DEBUG = true;

const App = () => {
  const [gigs, setGigs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const lastBoundsRef = useRef(null);
  
  // Search filters state
  const [searchFilters, setSearchFilters] = useState({
    actIds: [],
    startDate: '',
    endDate: ''
  });
  
  // Acts data for the dropdown
  const [acts, setActs] = useState([]);
  const [loadingActs, setLoadingActs] = useState(false);

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

  // Fetch acts for dropdown on component mount
  useEffect(() => {
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

        setActs(formattedActs.sort((a, b) => a.label.localeCompare(b.label)));
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
    
    if (DEBUG) console.log('Fetching gigs with filters:', filters);
    
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
        params.append('act_ids', actIdValues.join(','));
        if (DEBUG) console.log('Filtering by acts:', actIdValues);
      }
      
      if (filters.startDate) {
        params.append('start_date', filters.startDate);
      }
      
      if (filters.endDate) {
        params.append('end_date', filters.endDate);
      }
      
      if (DEBUG) console.log(`API call: /api/gigs?${params}`);
      
      const response = await fetch(`/api/gigs?${params}`);
      if (!response.ok) throw new Error('Failed to fetch gigs');
      
      const data = await response.json();
      if (DEBUG) console.log(`Received ${data.length} gigs from API`);
      
      setGigs(data);
    } catch (err) {
      console.error('Error fetching gigs:', err);
      setError('Failed to load gigs. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [setGigs, setError, setLoading]);
  
  // Handle map bounds changes
  const handleBoundsChange = useCallback((bounds) => {
    // Skip if bounds haven't changed significantly
    if (areBoundsSame(bounds, lastBoundsRef.current)) return;
    
    if (DEBUG) console.log('Map bounds changed');
    lastBoundsRef.current = bounds;
    
    // Fetch gigs with current filters
    fetchGigsForBounds(bounds, searchFilters);
  }, [fetchGigsForBounds, searchFilters]);

  // Handle search filter changes
  const handleFilterChange = useCallback((name, value) => {
    if (DEBUG) console.log(`Filter changing: ${name} = ${value}`);
    
    // Update the filter state
    const newFilters = {
      ...searchFilters,
      [name]: value
    };
    
    // Set the new filters
    setSearchFilters(newFilters);
    
    // Trigger an API call with the new filters
    if (lastBoundsRef.current) {
      fetchGigsForBounds(lastBoundsRef.current, newFilters);
    }
  }, [fetchGigsForBounds, searchFilters]);
  
  // Special handler for multi-select acts
  const handleActsChange = useCallback((selectedOptions) => {
    if (DEBUG) console.log('Acts selection changed:', selectedOptions);
    
    const newFilters = {
      ...searchFilters,
      actIds: selectedOptions || [] // Handle null when all options are cleared
    };
    
    setSearchFilters(newFilters);
    
    if (lastBoundsRef.current) {
      fetchGigsForBounds(lastBoundsRef.current, newFilters);
    }
  }, [fetchGigsForBounds, searchFilters]);
  
  // Clear all filters
  const handleClearFilters = useCallback(() => {
    if (DEBUG) console.log('Clearing all filters');
    
    const clearedFilters = { actIds: [], startDate: '', endDate: '' };
    setSearchFilters(clearedFilters);
    
    if (lastBoundsRef.current) {
      fetchGigsForBounds(lastBoundsRef.current, clearedFilters);
    }
  }, [fetchGigsForBounds]);
  
  // Initial data fetch when component mounts
  useEffect(() => {
    if (DEBUG) console.log('Component mounted');
  }, []);

  return (
    <div className="h-screen w-screen overflow-hidden flex flex-col bg-gray-100">
      <header className="bg-white shadow-sm top-0">
        <div className="w-full p-1 flex flex-wrap items-center gap-2">
          
          {/* Integrated Search Form */}
          <div className="flex flex-1 flex-wrap gap-0">

            {/* Start date */}
            <div className="basis-1/2 sm:basis-auto p-2">
              <p className="text-xs text-gray-600">From</p>
              <input
                type="date"
                className="w-full py-1 px-2 border border-gray-300 rounded-md text-sm focus:ring-purple-500 focus:border-purple-500"
                value={searchFilters.startDate}
                onChange={(e) => handleFilterChange('startDate', e.target.value)}
                placeholder="Start Date"
              />
            </div>
            
            {/* End date */}
            <div className="basis-1/2 sm:basis-auto p-2">
              <p className="text-xs text-gray-600">To</p>
              <input
                type="date"
                className="w-full py-1 px-2 border border-gray-300 rounded-md text-sm focus:ring-purple-500 focus:border-purple-500"
                value={searchFilters.endDate}
                onChange={(e) => handleFilterChange('endDate', e.target.value)}
                placeholder="End Date"
              />
            </div>           

            {/* Act multi-select dropdown with thumbnails */}
            <div className="basis-full sm:basis-auto flex-1 p-2">
              <div className="grow">
                <Select
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
          </div>
          
          <div className="flex flex-col sm:flex-row gap-2 items-center">
            {/* Clear filters button */}
            <button
                onClick={handleClearFilters}
                className="flex-none py-1 px-3 text-sm border border-gray-300 rounded-md hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-purple-500"
              >
                Clear
            </button>

            <div className="w-16 flex justify-center">
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
