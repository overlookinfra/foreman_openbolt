import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { Card, CardBody, FormGroup, Spinner } from '@patternfly/react-core';
import ParameterField from './ParameterField';
import EmptyContent from './EmptyContent';

const Loading = () => (
  <div style={{ textAlign: 'center', padding: '2rem' }}>
    <Spinner size="lg" />
    <p>{__('Loading Bolt options...')}</p>
  </div>
);

const Options = ({ sortedOptions, values, onChange }) =>
  sortedOptions.map(([optionName, metadata]) => (
    <ParameterField
      key={optionName}
      name={optionName}
      metadata={metadata}
      value={values[optionName]}
      onChange={onChange}
      showRequired={false}
    />
  ));

Options.propTypes = {
  sortedOptions: PropTypes.arrayOf(PropTypes.array).isRequired,
  values: PropTypes.object.isRequired,
  onChange: PropTypes.func.isRequired,
};

const BoltOptionsSection = ({
  selectedProxy,
  boltOptionsMetadata,
  boltOptions,
  onOptionChange,
  isLoading,
}) => {
  const isBooleanType = metadata =>
    metadata.type === 'boolean' || metadata.type === 'Optional[Boolean]';

  // Sort options to group booleans at the top to make the UI cleaner
  const sortedOptions = !boltOptionsMetadata
    ? []
    : Object.entries(boltOptionsMetadata).sort(
        ([_nameA, metadataA], [_nameB, metadataB]) => {
          const aIsBoolean = isBooleanType(metadataA);
          const bIsBoolean = isBooleanType(metadataB);

          if (aIsBoolean && !bIsBoolean) return -1;
          if (!aIsBoolean && bIsBoolean) return 1;
          return 0;
        }
      );

  const render = () => {
    if (isLoading) return <Loading />;
    if (!selectedProxy)
      return (
        <EmptyContent title={__('Select a Smart Proxy to see Bolt options')} />
      );
    if (sortedOptions.length === 0)
      return <EmptyContent title={__('No Bolt options available')} />;

    return (
      <Options
        sortedOptions={sortedOptions}
        values={boltOptions}
        onChange={onOptionChange}
      />
    );
  };

  return (
    <FormGroup label={__('Bolt Options')} fieldId="bolt-options">
      <Card>
        <CardBody>{render()}</CardBody>
      </Card>
    </FormGroup>
  );
};

BoltOptionsSection.propTypes = {
  selectedProxy: PropTypes.string.isRequired,
  boltOptionsMetadata: PropTypes.object.isRequired,
  boltOptions: PropTypes.object.isRequired,
  onOptionChange: PropTypes.func.isRequired,
  isLoading: PropTypes.bool.isRequired,
};

export default BoltOptionsSection;
