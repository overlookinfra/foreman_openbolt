import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { Popover, Button } from '@patternfly/react-core';

const HostsDisplay = ({ targets }) => {
  if (!targets || targets.length === 0) {
    return <>{__('No targets specified')}</>;
  }

  const popoverContent = (
    <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
      <ul style={{ paddingLeft: '1.5rem', margin: 0 }}>
        {targets.map((host, index) => (
          <li key={index} className="pf-v5-u-font-family-monospace">
            {host}
          </li>
        ))}
      </ul>
    </div>
  );

  return (
    <Popover
      headerContent={targets.length}
      bodyContent={popoverContent}
      position="right"
      maxWidth="400px"
    >
      <Button variant="link" isInline>
        {targets.length}
      </Button>
    </Popover>
  );
};

HostsDisplay.propTypes = {
  targets: PropTypes.arrayOf(PropTypes.string),
};

HostsDisplay.defaultProps = {
  targets: [],
};

export default HostsDisplay;
