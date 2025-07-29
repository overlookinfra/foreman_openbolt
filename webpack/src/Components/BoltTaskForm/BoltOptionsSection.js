import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import {
  Card,
  CardBody,
  EmptyState,
  EmptyStateIcon,
  EmptyStateHeader,
  FormGroup,
  Spinner
} from '@patternfly/react-core';
import { CogIcon } from '@patternfly/react-icons';
import ParameterField from './ParameterField';

const BoltOptionsSection = ({ 
  selectedProxy, 
  boltOptionsMetadata, 
  boltOptions, 
  onOptionChange,
  isLoading 
}) => {
  const isBooleanType = (metadata) => {
    return metadata.type === 'boolean' || metadata.type === 'Optional[Boolean]';
  };

  // Sort options to group booleans at the top to make the UI cleaner
  const sortedOptions = !boltOptionsMetadata ? [] : 
    Object.entries(boltOptionsMetadata).sort(([nameA, metadataA], [nameB, metadataB]) => {
      const aIsBoolean = isBooleanType(metadataA);
      const bIsBoolean = isBooleanType(metadataB);
      
      if (aIsBoolean && !bIsBoolean) return -1;
      if (!aIsBoolean && bIsBoolean) return 1;
      return 0;
    });

  return (
    <FormGroup
      label={__('Bolt Options')}
      fieldId="bolt-options"
    >
      <Card>
        <CardBody>
          {isLoading ? (
            <div style={{ textAlign: 'center', padding: '2rem' }}>
              <Spinner size="lg" />
              <p>{__('Loading Bolt options...')}</p>
            </div>
          ) : !selectedProxy ? (
            <EmptyState>
              <EmptyStateHeader 
                titleText={__('Select a Smart Proxy to see Bolt options')}
                icon={<EmptyStateIcon icon={CogIcon} />}
                headingLevel="h4"
              />
            </EmptyState>
          ) : sortedOptions.length > 0 ? (
            sortedOptions.map(([optionName, metadata]) => (
              <ParameterField
                key={optionName}
                name={optionName}
                metadata={metadata}
                value={boltOptions[optionName]}
                onChange={onOptionChange}
                showRequired={false}
              />
            ))
          ) : (
            <EmptyState>
              <EmptyStateHeader 
                titleText={__('No Bolt options available')}
                icon={<EmptyStateIcon icon={CogIcon} />}
                headingLevel="h4"
              />
            </EmptyState>
          )}
        </CardBody>
      </Card>
    </FormGroup>
  );
};

export default BoltOptionsSection;
