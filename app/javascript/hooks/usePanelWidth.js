import { useEffect, useState } from 'react';

const KEY = 'panelWidth';
export const DEFAULT_WIDTH = 352; // 22rem
const MIN_WIDTH = 280;
const MAX_SHARE = 0.6; // of the window, so the map keeps some room

const clamp = (width) => Math.round(Math.min(Math.max(width, MIN_WIDTH), Math.max(window.innerWidth * MAX_SHARE, MIN_WIDTH)));

const storedWidth = () => {
  try {
    const width = Number(localStorage.getItem(KEY));
    return width ? clamp(width) : DEFAULT_WIDTH;
  } catch {
    return DEFAULT_WIDTH;
  }
};

// The desktop sidebar's width in pixels, as the viewer last dragged it, kept
// between MIN_WIDTH and MAX_SHARE of the window as that resizes.
// setWidth stores what it's given, clamped.
export default function usePanelWidth() {
  const [ width, setStored ] = useState(storedWidth);

  useEffect(() => {
    const handleResize = () => setStored(clamp);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const setWidth = (next) => {
    const width = clamp(next);
    setStored(width);
    try { localStorage.setItem(KEY, width); } catch { /* private window: this visit only */ }
  };

  return [ width, setWidth, { min: MIN_WIDTH, max: clamp(Infinity) } ];
}
