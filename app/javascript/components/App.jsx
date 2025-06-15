import React, { useState, useEffect } from 'react';
import MapView from './MapView';

const App = () => {
  const [gigs, setGigs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchGigs = async () => {
      try {
        const response = await fetch('/api/gigs');
        if (!response.ok) {
          throw new Error('Failed to fetch comedy gigs');
        }
        const data = await response.json();
        setGigs(data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchGigs();
  }, []);

  return (
    <div className="h-screen w-screen overflow-hidden flex flex-col bg-gray-100">
      <header className="bg-white shadow-sm sticky top-0 z-50">
        <div className="w-full px-4 py-3 flex justify-between items-center">
          <h1 className="text-xl sm:text-2xl lg:text-3xl font-bold text-gray-900">Comedy Gigs Map</h1>
          <div className="flex items-center space-x-4">
            <span className="hidden sm:inline text-sm text-gray-600">{gigs.length} gigs found</span>
          </div>
        </div>
      </header>

      <main className="flex-1 relative">
        {loading ? (
          <div className="absolute inset-0 flex items-center justify-center bg-white bg-opacity-90">
            <div className="text-center">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mb-4"></div>
              <p className="text-lg text-gray-600">Loading gigs...</p>
            </div>
          </div>
        ) : error ? (
          <div className="absolute inset-0 flex items-center justify-center bg-white bg-opacity-90">
            <div className="text-center px-4">
              <div className="rounded-full h-12 w-12 bg-red-100 text-red-600 flex items-center justify-center mx-auto mb-4">
                <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <p className="text-lg text-red-600 font-medium">{error}</p>
            </div>
          </div>
        ) : (
          <div className="h-full w-full">
            <MapView gigs={gigs} />
          </div>
        )}
      </main>
    </div>
  );
};

export default App;
