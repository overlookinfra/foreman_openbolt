import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import {
  FormGroup,
  FormSelect,
  FormSelectOption
} from '@patternfly/react-core';

const SmartProxySelect = ({ 
  smartProxies, 
  selectedProxy, 
  onProxyChange, 
  isLoading = false 
}) => {
  return (
    <FormGroup
      label={__('Smart Proxy')}
      fieldId="smart-proxy-input"
    >
      <FormSelect
        id="proxy-select"
        value={selectedProxy}
        onChange={onProxyChange}
        isDisabled={isLoading}
        title={__('Select a Smart Proxy to run the task from.')}
        // Foreman tries injecting select2 which breaks this component
        className="without_select2"
      >
        <FormSelectOption
          key="select-smart-proxy"
          value=""
          label={isLoading ? __('Loading...') : __('Select Smart Proxy')} 
          isPlaceholder={true}
        />
        {smartProxies.map(proxy => (
          <FormSelectOption 
            key={proxy.id}
            value={proxy.id}
            label={proxy.name} 
          />
        ))}
      </FormSelect>
    </FormGroup>
  );
};

export default SmartProxySelect;
