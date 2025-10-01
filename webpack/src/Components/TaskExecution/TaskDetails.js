import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import {
  Card,
  CardBody,
  DescriptionList,
  DescriptionListDescription,
  DescriptionListGroup,
  DescriptionListTerm,
} from '@patternfly/react-core';
import { Table, Thead, Tbody, Tr, Th, Td } from '@patternfly/react-table';

const TaskDetails = ({ taskName, taskDescription, taskParameters }) => {
  const displayValue = value => {
    if (value === null || value === undefined) {
      return '-';
    }
    if (typeof value === 'object') {
      return JSON.stringify(value);
    }
    return String(value);
  };

  return (
    <Card>
      <CardBody>
        <DescriptionList isHorizontal>
          <DescriptionListGroup>
            <DescriptionListTerm>{__('Task Name')}</DescriptionListTerm>
            <DescriptionListDescription>
              <span className="pf-v5-u-font-family-monospace">{taskName}</span>
            </DescriptionListDescription>
          </DescriptionListGroup>

          {taskDescription && (
            <DescriptionListGroup>
              <DescriptionListTerm>{__('Description')}</DescriptionListTerm>
              <DescriptionListDescription>
                {taskDescription}
              </DescriptionListDescription>
            </DescriptionListGroup>
          )}

          {taskParameters && Object.keys(taskParameters).length > 0 && (
            <DescriptionListGroup>
              <DescriptionListTerm>{__('Parameters')}</DescriptionListTerm>
              <DescriptionListDescription>
                <Table
                  variant="compact"
                  borders
                  isStriped
                  gridBreakPoint="grid-md"
                  style={{ wordBreak: 'break-word' }}
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
                        <Td>
                          <span className="pf-v5-u-font-family-monospace">
                            {key}
                          </span>
                        </Td>
                        <Td>
                          <span className="pf-v5-u-font-family-monospace">
                            {displayValue(value)}
                          </span>
                        </Td>
                      </Tr>
                    ))}
                  </Tbody>
                </Table>
              </DescriptionListDescription>
            </DescriptionListGroup>
          )}
        </DescriptionList>
      </CardBody>
    </Card>
  );
};

TaskDetails.propTypes = {
  taskName: PropTypes.string.isRequired,
  taskDescription: PropTypes.string,
  taskParameters: PropTypes.object,
};

TaskDetails.defaultProps = {
  taskDescription: null,
  taskParameters: {},
};

export default TaskDetails;
