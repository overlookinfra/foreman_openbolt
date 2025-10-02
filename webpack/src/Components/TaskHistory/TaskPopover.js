import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { Popover, Button } from '@patternfly/react-core';
import { Table, Thead, Tbody, Tr, Th, Td } from '@patternfly/react-table';

const TaskPopover = ({ taskName, taskDescription, taskParameters }) => {
  const hasParameters =
    taskParameters && Object.keys(taskParameters).length > 0;

  const displayValue = value => {
    if (value === null || value === undefined) {
      return '-';
    }
    if (typeof value === 'object') {
      return JSON.stringify(value);
    }
    return String(value);
  };

  const popoverContent = (
    <div style={{ maxWidth: '500px' }}>
      {taskDescription && (
        <div style={{ marginBottom: '1rem' }}>
          <strong>{__('Description:')}</strong>
          <p>{taskDescription}</p>
        </div>
      )}

      {hasParameters && (
        <div>
          <strong>{__('Parameters:')}</strong>
          <div
            style={{
              maxHeight: '300px',
              overflowY: 'auto',
            }}
          >
            <Table
              variant="compact"
              borders
              isStriped
              isStickyHeader
              style={{
                border: '1px solid var(--pf-v5-global--BorderColor--100)',
              }}
            >
              <Thead>
                <Tr>
                  <Th width={30}>{__('Name')}</Th>
                  <Th width={70}>{__('Value')}</Th>
                </Tr>
              </Thead>
              <Tbody>
                {Object.entries(taskParameters).map(([key, value]) => (
                  <Tr key={key}>
                    <Td className="pf-v5-u-font-family-monospace">{key}</Td>
                    <Td className="pf-v5-u-font-family-monospace">
                      {displayValue(value)}
                    </Td>
                  </Tr>
                ))}
              </Tbody>
            </Table>
          </div>
        </div>
      )}

      {!taskDescription && !hasParameters && (
        <div>{__('No additional details available')}</div>
      )}
    </div>
  );

  return (
    <Popover bodyContent={popoverContent} position="right">
      <Button variant="link" isInline className="pf-v5-u-font-family-monospace">
        {taskName}
      </Button>
    </Popover>
  );
};

TaskPopover.propTypes = {
  taskName: PropTypes.string.isRequired,
  taskDescription: PropTypes.string,
  taskParameters: PropTypes.object,
};

TaskPopover.defaultProps = {
  taskDescription: null,
  taskParameters: {},
};

export default TaskPopover;
