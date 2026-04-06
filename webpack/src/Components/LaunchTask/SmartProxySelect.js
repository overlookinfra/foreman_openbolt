import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import {
  FormGroup,
  FormSelect,
  FormSelectOption,
} from '@patternfly/react-core';

const SmartProxySelect = ({
  smartProxies,
  selectedProxy,
  onProxyChange,
  isLoading = false,
}) => (
  <FormGroup label={__('Smart Proxy')} fieldId="smart-proxy-input">
    <FormSelect
      id="smart-proxy-input"
      value={selectedProxy}
      onChange={onProxyChange}
      isDisabled={isLoading}
      aria-label={__('Select Smart Proxy')}
      title={__('Select a Smart Proxy to run the task from.')}
      // Foreman tries injecting select2 which breaks this component
      className="without_select2"
    >
      <FormSelectOption
        key="select-smart-proxy"
        value=""
        label={isLoading ? __('Loading...') : __('Select Smart Proxy')}
        isPlaceholder
      />
      {smartProxies.map(proxy => (
        <FormSelectOption key={proxy.id} value={proxy.id} label={proxy.name} />
      ))}
    </FormSelect>
  </FormGroup>
);

SmartProxySelect.propTypes = {
  smartProxies: PropTypes.arrayOf(
    PropTypes.shape({
      id: PropTypes.oneOfType([PropTypes.string, PropTypes.number]).isRequired,
      name: PropTypes.string.isRequired,
    })
  ).isRequired,
  selectedProxy: PropTypes.string.isRequired,
  onProxyChange: PropTypes.func.isRequired,
  isLoading: PropTypes.bool.isRequired,
};

export default SmartProxySelect;
