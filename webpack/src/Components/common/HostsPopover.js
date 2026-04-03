import React from 'react';
import PropTypes from 'prop-types';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import { Popover, Button } from '@patternfly/react-core';
import { Table, Tbody, Tr, Td } from '@patternfly/react-table';

const HostsPopover = ({ targets }) => {
  if (!targets || targets.length === 0) {
    return <>{__('No targets specified')}</>;
  }

  const popoverContent = (
    <div
      style={{
        maxHeight: '300px',
        overflowY: 'auto',
        border: '1px solid var(--pf-v5-global--BorderColor--100)',
      }}
    >
      <Table
        variant="compact"
        borders
        isStriped
        aria-label={__('Target hosts')}
      >
        <Tbody>
          {targets.map((host, index) => (
            <Tr key={index}>
              <Td className="pf-v5-u-font-family-monospace">{host}</Td>
            </Tr>
          ))}
        </Tbody>
      </Table>
    </div>
  );

  return (
    <Popover bodyContent={popoverContent} position="right" maxWidth="600px">
      <Button
        variant="link"
        isInline
        aria-label={sprintf(__('%s target hosts'), targets.length)}
      >
        {targets.length}
      </Button>
    </Popover>
  );
};

HostsPopover.propTypes = {
  targets: PropTypes.arrayOf(PropTypes.string),
};

HostsPopover.defaultProps = {
  targets: [],
};

export default HostsPopover;
