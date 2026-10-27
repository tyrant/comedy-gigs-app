import { useCallback, useEffect, useState } from 'react';

// Fetches JSON whenever the URL changes, aborting the previous request. Keeps
// the last good data while the next request loads, so the map doesn't flicker.
// A null URL fetches nothing.
export default function useJson(url) {
  const [ state, setState ] = useState({ data: null, error: null, loading: Boolean(url) });
  const [ attempt, setAttempt ] = useState(0);

  useEffect(() => {
    if (!url) {
      setState({ data: null, error: null, loading: false });
      return;
    }

    const controller = new AbortController();
    setState(prev => ({ ...prev, error: null, loading: true }));

    fetch(url, { signal: controller.signal, headers: { Accept: 'application/json' } })
      .then(response => {
        if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
        return response.json();
      })
      .then(data => setState({ data, error: null, loading: false }))
      .catch(error => {
        if (error.name === 'AbortError') return;
        console.error(`Failed to load ${url}:`, error);
        setState(prev => ({ ...prev, error, loading: false }));
      });

    return () => controller.abort();
  }, [ url, attempt ]);

  const retry = useCallback(() => setAttempt(n => n + 1), []);

  return { ...state, retry };
}
