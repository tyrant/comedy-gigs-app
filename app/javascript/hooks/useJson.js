import { useCallback, useEffect, useState } from 'react';

// Fetches JSON whenever the URL changes, aborting the previous request. Keeps
// the last good data while the next request loads, so the map doesn't flicker.
// A null URL fetches nothing.
//
// loading is true from the very render that changes the URL, not only once
// the fetch has started, so nothing (people or specs) sees a moment where the
// filters have changed but the old results look settled.
export default function useJson(url) {
  const [ state, setState ] = useState({ data: null, error: null, loading: Boolean(url), url });
  const [ attempt, setAttempt ] = useState(0);

  useEffect(() => {
    if (!url) {
      setState({ data: null, error: null, loading: false, url });
      return;
    }

    const controller = new AbortController();
    setState(prev => ({ ...prev, error: null, loading: true, url }));

    fetch(url, { signal: controller.signal, headers: { Accept: 'application/json' } })
      .then(response => {
        if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
        return response.json();
      })
      .then(data => setState({ data, error: null, loading: false, url }))
      .catch(error => {
        if (error.name === 'AbortError') return;
        console.error(`Failed to load ${url}:`, error);
        setState(prev => ({ ...prev, error, loading: false }));
      });

    return () => controller.abort();
  }, [ url, attempt ]);

  const retry = useCallback(() => setAttempt(n => n + 1), []);

  const { url: requested, ...result } = state;
  return { ...result, loading: result.loading || requested !== url, retry };
}
