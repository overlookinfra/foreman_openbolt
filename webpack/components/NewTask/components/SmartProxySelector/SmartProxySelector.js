import React from 'react';

const SmartProxySelector = ({ smartProxies, value, onChange }) => (
  <div className="form-group">
    <label htmlFor="proxy_select" className="col-md-2 control-label">
      Smart Proxy
    </label>
    <div className="col-md-6">
      <select
        id="proxy_select"
        name="smart_proxy_id"
        className="form-control"
        value={value}
        onChange={e => onChange(e.target.value)}
        aria-required="true"
      >
        <option value="">Select Smart Proxy'</option>
        {smartProxies.map(p => (
          <option key={p.id} value={p.id}>{p.name}</option>
        ))}
      </select>
    </div>
  </div>
);

export default SmartProxySelector;
