import React, { useState, useCallback, useRef } from 'react';
import MapView from './MapView';
import { normalizeLongitude } from '../fiddly-bits';

const App = () => {
  const [gigs, setGigs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const lastBoundsRef = useRef(null);

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

  const handleBoundsChange = useCallback(async (bounds) => {
    // Skip if bounds haven't changed significantly
    if (areBoundsSame(bounds, lastBoundsRef.current)) return;
    lastBoundsRef.current = bounds;

    setError(null);
    setLoading(true);

    const fetchGigsForBounds = async (bounds) => {
      const params = new URLSearchParams({
        north: bounds.getNorth(),
        south: bounds.getSouth(),
        east: normalizeLongitude(bounds.getEast()),
        west: normalizeLongitude(bounds.getWest())
      });
      const response = await fetch(`/api/gigs?${params}`);
      if (!response.ok) throw new Error('Failed to fetch gigs');
      return await response.json();
    };

    try {
      setGigs(await fetchGigsForBounds(bounds));

    } catch (err) {
      console.error('Error fetching gigs:', err);
      setError('Failed to load gigs. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [setGigs, setError, setLoading]);

  return (
    <div className="h-screen w-screen overflow-hidden flex flex-col bg-gray-100">
      <header className="bg-white shadow-sm sticky top-0 z-50">
        <div className="w-full px-4 py-3 flex justify-between items-center">
          <h1 className="text-xl sm:text-2xl lg:text-3xl font-bold text-gray-900">Comedy Gigs Map</h1>
          <div className="flex items-center space-x-4">
            {loading ? (
              <div className="flex items-center space-x-2">
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-purple-600"></div>
                <span className="text-sm text-gray-600">Loading gigs...</span>
              </div>
            ) : error ? (
              <span className="text-sm text-red-600">{error}</span>
            ) : (
              <span className="text-sm text-gray-600">{gigs.length} gigs found</span>
            )}
          </div>
        </div>
      </header>

      <main className="flex-1 relative">
        <div className="h-full w-full">
          <MapView gigs={gigs} onBoundsChange={handleBoundsChange} />
        </div>
      </main>
    </div>
  );
};

export default App;
