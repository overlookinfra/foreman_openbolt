import React from 'react';

const ParameterField = ({ name, meta, prefix, showType = true }) => {
  const type = Array.isArray(meta.type) ? 'enum' : (meta.type || '').toLowerCase();
  const isBoolean = type === 'boolean' || type === 'optional[boolean]';
  const required = prefix !== 'options' && !type.startsWith('optional[');

  let input;
  if (type === 'enum') {
    input = (
      <select
        id={`${prefix}_${name}`}
        name={`${prefix}[${name}]`}
        className="form-control"
        defaultValue={meta.default || ''}
        required={required}
        aria-required={required}
      >
        {meta.type.map(v => <option key={v} value={v}>{v}</option>)}
      </select>
    );
  } else if (isBoolean) {
    input = (
      <input
        type="checkbox"
        id={`${prefix}_${name}`}
        name={`${prefix}[${name}]`}
        defaultChecked={!!meta.default}
      />
    );
  } else {
    input = (
      <input
        type="text"
        id={`${prefix}_${name}`}
        name={`${prefix}[${name}]`}
        className="form-control"
        defaultValue={meta.default || ''}
        required={required}
        aria-required={required}
      />
    );
  }

  return (
    <div className="form-group">
      <label htmlFor={`${prefix}_${name}`} className="control-label">
        {name}
        {required && <span className="required-input" aria-hidden="true">*</span>}
        {showType && !isBoolean && meta.type && (
          <span
            className="help-inline text-muted"
            title={Array.isArray(meta.type) ? meta.type.join(', ') : meta.type}
            aria-label={Array.isArray(meta.type) ? meta.type.join(', ') : meta.type}
          >
            {Array.isArray(meta.type) ? meta.type.join(', ') : meta.type}
          </span>
        )}
      </label>
      {input}
      {meta.description && (
        <span className="help-block" id={`${prefix}_${name}_help`}>
          {meta.description}
        </span>
      )}
    </div>
  );
};

export default ParameterField;
