import React from 'react';
import './RunButton.scss';

const RunButton = ({ disabled }) => (
  <div className="form-group">
    <div className="col-md-offset-2 col-md-6">
      <button
        type="submit"
        className="btn btn-primary"
        id="run_task_btn"
        disabled={disabled}
      >
        Run Task
      </button>
    </div>
  </div>
);

export default RunButton;
