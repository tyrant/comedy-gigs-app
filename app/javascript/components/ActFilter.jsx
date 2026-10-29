import React, { useCallback, useEffect, useRef, useState } from 'react';
import AsyncSelect from 'react-select/async';
import { components } from 'react-select';
import { debounce, pluralize } from '../fiddly-bits';

// Avatars are 32px plus margins; the rest of the control (clear, dropdown
// arrow, "+N more") takes about 110px.
const AVATAR_WIDTH = 32;
const CONTROL_CHROME = 110;

const toOption = (act) => ({ value: act.id, label: act.name, image: act.image, upcomingGigs: act.upcoming_gigs });

const fetchActs = async (query) => {
  const response = await fetch(`/api/acts?${query}`, { headers: { Accept: 'application/json' } });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return (await response.json()).map(toOption);
};

// Defined once, at module scope, so react-select doesn't remount them on every render.
// An avatar opens the act’s view; it keeps its mouse and keys from react-select,
// which would open the menu instead.
const MultiValueLabel = ({ data, selectProps }) => (
  <button type="button" onMouseDown={(e) => e.stopPropagation()} onKeyDown={(e) => e.stopPropagation()} onClick={() => selectProps.onSelectAct(data.value)}
    aria-label={`Show ${data.label}’s gigs`} title={data.label} className="block cursor-pointer rounded-full">
    <img src={data.image} alt={data.label}
      width={AVATAR_WIDTH} height={AVATAR_WIDTH} loading="lazy" decoding="async"
      className="size-8 rounded-full object-cover" />
  </button>
);

const MultiValue = (props) => {
  const { index, selectProps } = props;
  return index < selectProps.maxVisible ? <components.MultiValue {...props} /> : null;
};

const ValueContainer = ({ children, ...props }) => {
  const hidden = Math.max(props.getValue().length - props.selectProps.maxVisible, 0);

  return (
    <components.ValueContainer {...props}>
      {children}
      {hidden > 0 && (
        <span className="ml-1 shrink-0 rounded-full bg-surface-2 px-2 py-1 text-xs text-muted">+{hidden} more</span>
      )}
    </components.ValueContainer>
  );
};

const formatOptionLabel = (option, { context }) => context === 'menu' && (
  <div className="flex items-center gap-2">
    <img src={option.image} alt="" width={AVATAR_WIDTH} height={AVATAR_WIDTH} loading="lazy" decoding="async"
      className="size-8 shrink-0 rounded-full object-cover" />
    <span className="truncate text-sm">{option.label}</span>
    {option.upcomingGigs > 0 && <span className="ml-auto shrink-0 text-xs text-muted">{pluralize(option.upcomingGigs, 'gig')}</span>}
  </div>
);

const selectComponents = { MultiValue, MultiValueLabel, ValueContainer };

// Layout only: colours come from the .react-select__* rules in the stylesheet
const selectStyles = {
  control: (base) => ({ ...base, flexWrap: 'nowrap' }),
  valueContainer: (base) => ({ ...base, flexWrap: 'nowrap', padding: '2px 8px', gap: 0 }),
  multiValue: (base) => ({ ...base, position: 'relative', margin: '0 -4px 0 0', borderRadius: '9999px', flexShrink: 0 }),
  multiValueLabel: (base) => ({ ...base, padding: 0 }),
  multiValueRemove: (base) => ({
    ...base, position: 'absolute', top: -4, right: -4, width: 16, height: 16, padding: 0,
    justifyContent: 'center', borderRadius: '9999px'
  }),
  menu: (base) => ({ ...base, zIndex: 1000 })
};

// Multi-select of acts, searched on the server as you type. The URL only holds
// act IDs, so the chosen acts' names and images are fetched once on load.
const ActFilter = ({ actIds, onChange, onSelectAct }) => {
  const containerRef = useRef(null);
  const [ known, setKnown ] = useState(() => new Map()); // act ID -> option
  const [ maxVisible, setMaxVisible ] = useState(4);

  // Look up any act in the URL we don't have a name for yet
  useEffect(() => {
    const missing = actIds.filter(id => !known.has(id));
    if (!missing.length) return;

    fetchActs(`ids=${missing.join(',')}`)
      .then(options => setKnown(prev => new Map([ ...prev, ...options.map(o => [ o.value, o ]) ])))
      .catch(error => console.error('Failed to load selected acts:', error));
  }, [ actIds ]);

  // Fit as many avatars as the control has room for
  useEffect(() => {
    const observer = new ResizeObserver(([ entry ]) => {
      setMaxVisible(Math.max(Math.floor((entry.contentRect.width - CONTROL_CHROME) / (AVATAR_WIDTH + 4)), 1));
    });
    observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, []);

  const loadOptions = useCallback(debounce((input, callback) => {
    fetchActs(input.trim() ? `q=${encodeURIComponent(input.trim())}` : '')
      .then(callback)
      .catch(error => {
        console.error('Act search failed:', error);
        callback([]);
      });
  }, 250), []);

  const handleChange = (options) => {
    setKnown(prev => new Map([ ...prev, ...options.map(o => [ o.value, o ]) ]));
    onChange(options.map(o => o.value));
  };

  const value = actIds.map(id => known.get(id)).filter(Boolean);

  return (
    <div id="acts" ref={containerRef} className="relative min-w-0 flex-1 basis-40">
      <AsyncSelect
        inputId="act_search"
        aria-label="Filter by act"
        name="acts"
        isMulti
        cacheOptions
        defaultOptions
        closeMenuOnSelect={false}
        loadOptions={loadOptions}
        value={value}
        onChange={handleChange}
        placeholder="Search comedians…"
        noOptionsMessage={({ inputValue }) => inputValue ? `No acts matching “${inputValue}”` : 'Type to search acts'}
        loadingMessage={() => 'Searching…'}
        classNamePrefix="react-select"
        unstyled
        components={selectComponents}
        styles={selectStyles}
        formatOptionLabel={formatOptionLabel}
        maxVisible={maxVisible}
        onSelectAct={onSelectAct}
      />
    </div>
  );
};

export default ActFilter;
