import React from 'react';
import { __ } from 'foremanReact/common/I18n';

const TargetsInput = ({ value, onChange }) => (
  <div className="form-group">
    <label htmlFor="targets" className="col-md-2 control-label">
      Targets
    </label>
    <div className="col-md-6">
      <input
        type="text"
        id="targets"
        name="targets"
        className="form-control"
        required
        aria-required="true"
        aria-describedby="targets-help"
        value={value}
        onChange={e => onChange(e.target.value)}
      />
      <span id="targets-help" className="help-block">
        Comma-separated list of targets (e.g., host1,host2,host3)
      </span>
    </div>
  </div>
);

export default TargetsInput;
