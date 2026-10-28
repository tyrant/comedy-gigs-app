import React, { useState } from 'react';
import { DATE_PRESETS, matchingPreset, presetDates } from '../fiddly-bits';

const fieldClass = 'h-10 rounded-md border border-line bg-surface px-2 text-sm shadow-xs hover:bg-surface-2';

const DateField = ({ id, label, value, min, onChange }) => (
  <label htmlFor={id} className="flex min-w-0 flex-1 items-center gap-1.5 text-sm text-muted sm:flex-none">
    <span className="shrink-0">{label}</span>
    <input
      type="date" id={id} name={id} value={value} min={min}
      onChange={(e) => onChange(e.target.value)}
      onClick={(e) => e.target.showPicker?.()}
      className={`${fieldClass} min-w-0 flex-1 cursor-pointer text-fg`}
    />
  </label>
);

// A menu of common ranges, plus the two dates themselves for anything else.
// On phones the dates only appear for a custom range, to save a row.
const DateRange = ({ startDate, endDate, onChange }) => {
  const [ customOpen, setCustomOpen ] = useState(false);
  const preset = matchingPreset({ startDate, endDate });
  const showDates = customOpen || !preset;

  const choose = (id) => {
    setCustomOpen(id === 'custom');
    if (id !== 'custom') onChange(presetDates(id));
  };

  return (
    <div className="flex flex-wrap items-center gap-2 max-md:order-2 max-md:basis-full">
      <select id="date_preset" aria-label="Dates" value={showDates ? 'custom' : preset} onChange={(e) => choose(e.target.value)}
        className={`${fieldClass} cursor-pointer font-medium max-sm:flex-1`}>
        {DATE_PRESETS.map(({ id, label }) => <option key={id} value={id}>{label}</option>)}
        <option value="custom">Custom dates</option>
      </select>
      <div className={`flex gap-2 max-sm:basis-full ${showDates ? '' : 'max-sm:hidden'}`}>
        <DateField id="start_date" label="From" value={startDate}
          onChange={(value) => onChange({ startDate: value, endDate })} />
        <DateField id="end_date" label="To" value={endDate} min={startDate}
          onChange={(value) => onChange({ startDate, endDate: value })} />
      </div>
    </div>
  );
};

export default DateRange;
