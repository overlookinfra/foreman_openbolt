import React from 'react';
import PropTypes from 'prop-types';
import {
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  ExpandableRowContent,
} from '@patternfly/react-table';
import { HelperText, HelperTextItem } from '@patternfly/react-core';
import { translate as __ } from 'foremanReact/common/I18n';

/**
 * FieldTable
 * Renders rows as: [chevron][Name] [Value]
 * Clicking the chevron expands a details row that spans all columns and shows Type + Description.
 *
 * PatternFly v5 expandable table references:
 * - Make first cell expandable via Td expand prop
 * - Wrap each parent/child pair in a Tbody with isExpanded
 * - Place details inside <ExpandableRowContent>
 */
const FieldTable = ({ rows }) => {
  // Track expanded state per row key
  const [expanded, setExpanded] = React.useState(() => ({}));

  const toggle = rowKey => {
    setExpanded(prev => ({ ...prev, [rowKey]: !prev[rowKey] }));
  };

  return (
    <Table
      variant="compact"
      isStriped
      gridBreakPoint="grid-md"
      style={{ wordBreak: 'break-word' }}
    >
      <Thead>
        <Tr>
          <Th aria-label="Row expand control" />
          <Th width={25}>Name</Th>
          <Th width={75}>Value</Th>
        </Tr>
      </Thead>

      {rows.map(
        // required is only relevant (currently) for ParametersSection
        // hasEncryptedDefault is only relevant for OpenBoltOptionsSection
        (
          {
            key,
            name,
            valueCell,
            type,
            description,
            required,
            hasEncryptedDefault,
          },
          rowIndex
        ) => {
          const rowKey = String(key || name || rowIndex);
          const isExpanded = !!expanded[rowKey];

          return (
            <Tbody key={rowKey} isExpanded={isExpanded}>
              <Tr>
                <Td
                  expand={{
                    rowIndex,
                    isExpanded,
                    onToggle: () => toggle(rowKey),
                  }}
                />
                <Td dataLabel="Name">
                  <span className="pf-v5-u-font-family-monospace">{name}</span>
                  {required && (
                    <span
                      style={{
                        color: 'red',
                        marginLeft: '0.25rem',
                      }}
                      title="Required"
                    >
                      *
                    </span>
                  )}
                </Td>
                <Td dataLabel="Value">{valueCell}</Td>
              </Tr>

              {(type || description) && (
                <Tr isExpanded={isExpanded}>
                  <Td noPadding colSpan={3}>
                    <ExpandableRowContent>
                      <HelperText component="ul">
                        {type && (
                          <HelperTextItem>
                            <strong>{__('Type:')}</strong> <code>{type}</code>
                          </HelperTextItem>
                        )}
                        {required && (
                          <HelperTextItem variant="error">
                            <strong>{__('This field is required')}</strong>
                          </HelperTextItem>
                        )}
                        {hasEncryptedDefault && (
                          <HelperTextItem variant="warning">
                            <strong>
                              {__(
                                'This field has a saved, encrypted default value. To use this value, do not change the field.'
                              )}
                            </strong>
                          </HelperTextItem>
                        )}
                        {description && (
                          <HelperTextItem>{description}</HelperTextItem>
                        )}
                      </HelperText>
                    </ExpandableRowContent>
                  </Td>
                </Tr>
              )}
            </Tbody>
          );
        }
      )}
    </Table>
  );
};

FieldTable.propTypes = {
  rows: PropTypes.arrayOf(
    PropTypes.shape({
      key: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
      name: PropTypes.string.isRequired,
      required: PropTypes.bool,
      valueCell: PropTypes.node.isRequired,
      type: PropTypes.string,
      description: PropTypes.node,
    })
  ).isRequired,
};

export default FieldTable;
