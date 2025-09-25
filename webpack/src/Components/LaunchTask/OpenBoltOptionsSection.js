import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { Card, CardBody, FormGroup, Spinner } from '@patternfly/react-core';
import ParameterField from './ParameterField';
import EmptyContent from './EmptyContent';

const Loading = () => (
  <div style={{ textAlign: 'center', padding: '2rem' }}>
    <Spinner size="lg" />
    <p>{__('Loading OpenBolt options...')}</p>
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

const OpenBoltOptionsSection = ({
  selectedProxy,
  openBoltOptionsMetadata,
  openBoltOptions,
  onOptionChange,
  isLoading,
}) => {
  const isBooleanType = metadata =>
    metadata.type === 'boolean' || metadata.type === 'Optional[Boolean]';

  // Sort options to group booleans at the top to make the UI cleaner
  const sortedOptions = (openBoltOptionsMetadata) => {
    if (!openBoltOptionsMetadata) return [];
    const { transport, ...rest } = openBoltOptionsMetadata;
    const entries = Object.entries(rest);

    entries.sort(([_nameA, metadataA], [_nameB, metadataB]) => {
        const aIsBoolean = isBooleanType(metadataA);
        const bIsBoolean = isBooleanType(metadataB);

        if (aIsBoolean !== bIsBoolean) return aIsBoolean ? -1 : 1;
        return 0;
      }
    );
    return [['transport', transport], ...entries];
  };

  const render = () => {
    if (isLoading) return <Loading />;
    if (!selectedProxy)
      return (
        <EmptyContent title={__('Select a Smart Proxy to see OpenBolt options')} />
      );
    if (sortedOptions.length === 0)
      return <EmptyContent title={__('No OpenBolt options available')} />;

    return (
      <Options
        sortedOptions={sortedOptions(openBoltOptionsMetadata)}
        values={openBoltOptions}
        onChange={onOptionChange}
      />
    );
  };

  return (
    <FormGroup label={__('OpenBolt Options')} fieldId="openbolt-options">
      <Card>
        <CardBody>{render()}</CardBody>
      </Card>
    </FormGroup>
  );
};

OpenBoltOptionsSection.propTypes = {
  selectedProxy: PropTypes.string.isRequired,
  openBoltOptionsMetadata: PropTypes.object.isRequired,
  openBoltOptions: PropTypes.object.isRequired,
  onOptionChange: PropTypes.func.isRequired,
  isLoading: PropTypes.bool.isRequired,
};

export default OpenBoltOptionsSection;
