import React, { useState, useCallback, useRef, useEffect } from 'react';
import MapView from './MapView';
import { normalizeLongitude } from '../fiddly-bits';

// Debug flag to log API calls
const DEBUG = true;

const App = () => {
  const [gigs, setGigs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const lastBoundsRef = useRef(null);
  
  // Search filters state
  const [searchFilters, setSearchFilters] = useState({
    actId: '',
    startDate: '',
    endDate: ''
  });
  
  // Acts dropdown data
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
        setActs(data.sort((a, b) => a.name.localeCompare(b.name)));
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
      if (filters.actId) {
        params.append('act_id', filters.actId);
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
  
  // Clear all filters
  const handleClearFilters = useCallback(() => {
    if (DEBUG) console.log('Clearing all filters');
    
    const clearedFilters = { actId: '', startDate: '', endDate: '' };
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
      <header className="bg-white shadow-sm sticky top-0 z-50">
        <div className="w-full px-4 py-3 flex flex-wrap items-center gap-4">
          <h1 className="text-xl font-bold text-gray-900">Comedy Gigs App</h1>
          
          {/* Integrated Search Form */}
          <div className="flex flex-1 flex-wrap items-center gap-3">
            {/* Act dropdown */}
            <div className="w-48">
              <select
                className="w-full py-1 px-2 border border-gray-300 rounded-md text-sm focus:ring-purple-500 focus:border-purple-500"
                value={searchFilters.actId}
                onChange={(e) => handleFilterChange('actId', e.target.value)}
                disabled={loadingActs}
              >
                <option value="">All Acts</option>
                {acts.map(act => (
                  <option key={act.id} value={act.id}>{act.name}</option>
                ))}
              </select>
            </div>
            
            {/* Start date */}
            <div className="w-40">
              <input
                type="date"
                className="w-full py-1 px-2 border border-gray-300 rounded-md text-sm focus:ring-purple-500 focus:border-purple-500"
                value={searchFilters.startDate}
                onChange={(e) => handleFilterChange('startDate', e.target.value)}
                placeholder="Start Date"
              />
            </div>
            
            {/* End date */}
            <div className="w-40">
              <input
                type="date"
                className="w-full py-1 px-2 border border-gray-300 rounded-md text-sm focus:ring-purple-500 focus:border-purple-500"
                value={searchFilters.endDate}
                onChange={(e) => handleFilterChange('endDate', e.target.value)}
                placeholder="End Date"
              />
            </div>
            
            {/* Clear filters button */}
            <button
              onClick={handleClearFilters}
              className="py-1 px-3 text-sm border border-gray-300 rounded-md hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-purple-500"
            >
              Clear
            </button>
          </div>
          
          {/* Status indicators */}
          <div className="flex items-center">
            {loading ? (
              <div className="flex items-center space-x-2">
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-purple-600"></div>
                <span className="text-sm text-gray-600">Loading...</span>
              </div>
            ) : error ? (
              <span className="text-sm text-red-600">{error}</span>
            ) : (
              <div className="flex items-center gap-2">
                <span className="text-sm text-gray-600">{gigs.length} gigs found</span>
                {(searchFilters.actId || searchFilters.startDate || searchFilters.endDate) && (
                  <span className="text-xs px-2 py-1 bg-purple-100 text-purple-800 rounded-full">
                    Filters applied
                  </span>
                )}
              </div>
            )}
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
