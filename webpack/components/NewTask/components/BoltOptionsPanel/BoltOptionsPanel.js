import React from 'react';
import LoadingBlankSlate from '../LoadingBlankSlate/LoadingBlankSlate';
import ParameterField    from '../ParameterField/ParameterField';
import './BoltOptionsPanel.scss';

const BoltOptionsPanel = ({ options, loading, i18n, hasProxy }) => (
  <div className="form-group">
    <label className="col-md-2 control-label">
      Bolt Options
    </label>
    <div className="col-md-8">
      <div
        id="bolt_options"
        className="well"
        role="region"
        aria-label="Bolt Options"
        aria-live="polite"
        aria-busy={loading}
      >
        {!hasProxy
          ? <LoadingBlankSlate icon="pficon pficon-settings" message={i18n.selectProxyForOptions} />
          : loading
            ? <LoadingBlankSlate icon="pficon pficon-settings" message={i18n.loadingOptions} />
            : Object.keys(options).length === 0
              ? <LoadingBlankSlate icon="pficon pficon-settings" message="No options available" />
              : Object.entries(options).map(([name, meta]) => (
                  <ParameterField key={name}
                                  name={name}
                                  meta={meta}
                                  prefix="options"
                                  showType={false} />
                ))
        }
      </div>
    </div>
  </div>
);

export default BoltOptionsPanel;
