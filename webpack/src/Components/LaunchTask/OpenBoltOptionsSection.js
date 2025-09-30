import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { FormGroup, Spinner } from '@patternfly/react-core';
import ParameterField from './ParameterField';
import FieldTable from './FieldTable';
import EmptyContent from './EmptyContent';
import { ENCRYPTED_DEFAULT_PLACEHOLDER } from '../common/constants';

const Loading = () => (
  <div style={{ textAlign: 'center', padding: '2rem' }}>
    <Spinner size="lg" />
    <p>{__('Loading OpenBolt options...')}</p>
  </div>
);

const Options = ({ sortedOptions, values, onChange }) => {
  const transport = values?.transport;
  const visibleOptions = sortedOptions.filter(([optionName, metadata]) => {
    if (optionName === 'transport') return true;
    if (!metadata.transport) return true;
    return metadata.transport.includes(transport);
  });

  const rows = visibleOptions.map(([optionName, metadata]) => ({
    key: optionName,
    name: optionName,
    valueCell: (
      // We don't want to show the type for OpenBolt options as
      // there are no complex types like there are for task parameters,
      // so we omit it here. Also, none should be marked as required, since
      // all options are optional except transport, which always has a value.
      <ParameterField
        name={optionName}
        metadata={metadata}
        value={values[optionName]}
        onChange={onChange}
      />
    ),
    description: metadata.description,
    hasEncryptedDefault:
      metadata.default && metadata.default === ENCRYPTED_DEFAULT_PLACEHOLDER,
  }));

  return <FieldTable rows={rows} />;
};

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
  const sortedOptions = metadata => {
    if (!metadata) return [];
    const { transport, ...rest } = metadata;
    const entries = Object.entries(rest);

    entries.sort(([_nameA, metadataA], [_nameB, metadataB]) => {
      const aIsBoolean = isBooleanType(metadataA);
      const bIsBoolean = isBooleanType(metadataB);

      if (aIsBoolean !== bIsBoolean) return aIsBoolean ? -1 : 1;
      return 0;
    });
    return [['transport', transport], ...entries];
  };

  const render = () => {
    if (isLoading) return <Loading />;
    if (!selectedProxy)
      return (
        <EmptyContent
          title={__('Select a Smart Proxy to see OpenBolt options')}
        />
      );
    const options = sortedOptions(openBoltOptionsMetadata);
    if (options.length === 0)
      return <EmptyContent title={__('No OpenBolt options available')} />;

    return (
      <Options
        sortedOptions={options}
        values={openBoltOptions}
        onChange={onOptionChange}
      />
    );
  };

  return (
    <FormGroup label={__('OpenBolt Options')} fieldId="openbolt-options">
      {render()}
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
