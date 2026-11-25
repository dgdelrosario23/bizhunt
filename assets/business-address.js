(function (root) {
  'use strict';
  const keys = ['address_line', 'address_city', 'address_province'];
  const clean = value => String(value ?? '').trim();
  const escape = value => clean(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  function parts(record = {}) {
    if (keys.some(key => record[key] != null)) return keys.map(key => clean(record[key]));
    const old = clean(record.location);
    const segments = old.split(',').map(clean);
    // Suggest components for legacy comma-separated addresses without rewriting the stored value.
    if (segments.length >= 3 && segments.every(Boolean)) return [segments.slice(0,-2).join(', '), ...segments.slice(-2)];
    if (segments.length === 2 && /\b(city|municipality)\b/i.test(segments[0])) return ['', ...segments];
    return [old, '', ''];
  }

  function fields(record = {}, {required = false, labelClass = '', group = false} = {}) {
    const values = parts(record);
    const labels = ['Building, street & area', 'City / municipality', 'Province'];
    const placeholders = ['18 Jesus St., Santo Rosario', 'Angeles City', 'Pampanga'];
    return keys.map((key, i) => `<label class="${escape(labelClass)}"${group ? ' data-edit-group="location"' : ''}>${labels[i]}<input name="${key}" value="${escape(values[i])}" maxlength="${i === 0 ? 140 : 50}" placeholder="${placeholders[i]}"${required ? ' required' : ''}${i === 0 ? '' : ' pattern="[^,]+"'}></label>`).join('');
  }

  function read(data, original = null) {
    const values = keys.map(key => clean(data.get(key)));
    if (original && values.every((value, i) => value === parts(original)[i])) return {location: original.location ?? ''};
    if (!values.every(Boolean) || values.slice(1).some(value => value.includes(','))) throw Error('Enter the building, street or area, city / municipality, and province in their separate fields.');
    if (values[0].length > 140 || values.slice(1).some(value => value.length > 50)) throw Error('Keep the address within the field limits.');
    return {location: values.join(', '), ...Object.fromEntries(keys.map((key, i) => [key, values[i]]))};
  }

  function hoursSummary(weekly = {}) {
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return days.map(day => {
      const short = day.slice(0,3), entry = weekly[day.toLowerCase()] || weekly[short.toLowerCase()];
      if (!entry) return '';
      return entry.closed ? `${short} Closed` : entry.open && entry.close ? `${short} ${entry.open}–${entry.close}` : '';
    }).filter(Boolean).join(' · ');
  }

  root.BizHuntAddress = Object.freeze({keys, parts, fields, read, hoursSummary});
})(typeof window === 'undefined' ? globalThis : window);
