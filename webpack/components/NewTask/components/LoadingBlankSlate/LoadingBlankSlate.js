import React from 'react';

const LoadingBlankSlate = ({ icon, message }) => (
  <div className="blank-slate-pf" role="status">
    <div className="blank-slate-pf-icon">
      <span className={icon} aria-hidden="true"></span>
    </div>
    <h4>{message}</h4>
  </div>
);

export default LoadingBlankSlate;
