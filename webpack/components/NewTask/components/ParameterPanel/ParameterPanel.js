import React from 'react';
import LoadingBlankSlate from '../LoadingBlankSlate/LoadingBlankSlate';
import ParameterField    from '../ParameterField/ParameterField';
import './ParameterPanel.scss';

const ParameterPanel = ({ parameters, loading, i18n, hasProxyAndTask }) => (
  <div className="form-group">
    <label className="col-md-2 control-label">
      Parameters
    </label>
    <div className="col-md-8">
      <div
        id="task_params"
        className="well"
        role="region"
        aria-label="Task Parameters"
        aria-live="polite"
        aria-busy={loading}
      >
        {loading
          ? <LoadingBlankSlate icon="pficon pficon-info" message={i18n.loadingParams} />
          : !hasProxyAndTask
            ? <LoadingBlankSlate icon="pficon pficon-info" message={i18n.selectProxyAndTask} />
            : Object.keys(parameters).length === 0
              ? <LoadingBlankSlate icon="pficon pficon-info" message="No parameters available" />
              : Object.entries(parameters).map(([name, meta]) => (
                  <ParameterField key={name} name={name} meta={meta} prefix="params" />
                ))
        }
      </div>
    </div>
  </div>
);

export default ParameterPanel;
