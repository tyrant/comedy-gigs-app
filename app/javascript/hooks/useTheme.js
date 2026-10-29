import { useEffect, useState } from 'react';
import useMediaQuery from './useMediaQuery';

const KEY = 'theme';
const THEME_COLOURS = { light: '#ffffff', dark: '#1b1b20' }; // the header's surface

const storedTheme = () => {
  try {
    const theme = localStorage.getItem(KEY);
    return theme === 'light' || theme === 'dark' ? theme : null;
  } catch {
    return null;
  }
};

// 'light' or 'dark': the viewer's choice once they've made one, else the
// system's, kept up to date. Mirrored onto <html data-theme>, which the
// layout sets before first paint.
export default function useTheme() {
  const systemDark = useMediaQuery('(prefers-color-scheme: dark)');
  const [ chosen, setChosen ] = useState(storedTheme);
  const theme = chosen || (systemDark ? 'dark' : 'light');

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', THEME_COLOURS[theme]);
  }, [ theme ]);

  const toggle = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    setChosen(next);
    try { localStorage.setItem(KEY, next); } catch { /* private window: this visit only */ }
  };

  return [ theme, toggle ];
}
