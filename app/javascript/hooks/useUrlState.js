import { useEffect, useRef, useState } from 'react';
import { writeUrlParams } from '../fiddly-bits';

// State that starts from the URL and is written back to it on every change
// (but not on load, so default values don't clutter a shared link).
export default function useUrlState(read, toParams) {
  const [ value, setValue ] = useState(read);
  const loaded = useRef(false);

  useEffect(() => {
    if (loaded.current) writeUrlParams(toParams(value));
    loaded.current = true;
  }, [ value ]);

  return [ value, setValue ];
}
