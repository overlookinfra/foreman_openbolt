import React from 'react';
import PropTypes from 'prop-types';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import { Popover, Button } from '@patternfly/react-core';
import { Table, Tbody, Tr, Td } from '@patternfly/react-table';

const HostGroupsPopover = ({ hostGroups }) => {
  if (!hostGroups || hostGroups.length === 0) {
    return <>{__('No host groups specified')}</>;
  }

  const popoverContent = (
    <div
      style={{
        maxHeight: '300px',
        overflowY: 'auto',
        border: '1px solid var(--pf-v5-global--BorderColor--100)',
      }}
    >
      <Table variant="compact" borders isStriped aria-label={__('Host groups')}>
        <Tbody>
          {hostGroups.map((hostGroup, index) => (
            <Tr key={index}>
              <Td className="pf-v5-u-font-family-monospace">{hostGroup}</Td>
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
        aria-label={sprintf(__('%s host groups'), hostGroups.length)}
      >
        {hostGroups.length}
      </Button>
    </Popover>
  );
};

HostGroupsPopover.propTypes = {
  hostGroups: PropTypes.arrayOf(PropTypes.string),
};

HostGroupsPopover.defaultProps = {
  hostGroups: [],
};

export default HostGroupsPopover;
