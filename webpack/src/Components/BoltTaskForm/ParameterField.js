import React from 'react';
import {
  Checkbox,
  FormGroup,
  FormHelperText,
  FormSelect,
  FormSelectOption,
  TextInput
} from '@patternfly/react-core';

const ParameterField = ({ name, metadata, value, showRequired, onChange }) => {
  /* Example task parameter metadata from the proxy:
   * {
   *   "action": {
   *     "description": "An action to take",
   *     "type": "Enum[get, set, delete]"
   *   },
   *   "section": {
   *     "description": "The section to modify",
   *     "type": "Optional[String[1]]"
   *   },
   *   "value": {
   *     "description": "The value to set",
   *     "type": "Variant[String[1],Integer[1,99]]"
   *   },
   *   "isEnabled": {
   *     "description": "Whether the section is enabled",
   *     "type": "Optional[Boolean]"
   *   }
   * }
   * 
   * Example Bolt Options parameter metadata from the proxy (see BOLT_OPTIONS in main.rb of the proxy code):
   * {
   *   "noop": {
   *     "type": "boolean",
   *     "default": false,
   *   },
   *   "user": {
   *     "type": "string"
   *   },
   *   "transport": {
   *     "type": ["ssh", "winrm"],
   *     "default": "ssh"
   *   }
   * }
   */
  const { type, default: defaultValue = null, description = null } = metadata;
  const isRequired = showRequired && !type?.toString().toLowerCase().startsWith('optional[');
  const fieldId = `param_${name}`;

  const renderInput = () => {
    if (Array.isArray(type)) {
      return (
        <FormSelect
          id={fieldId}
          title={description || name}
          value={value || defaultValue || ''}
          onChange={(_event, value) => onChange(name, value)}
          required={isRequired}
        >
          {type.map(option => (
            <FormSelectOption
              key={option}
              value={option}
              label={option}
            />
          ))}
        </FormSelect>
      );
    } else if (type === 'boolean' || type === 'Optional[Boolean]') {
      return (
        // Booleans should never set isRequired since we'll always have a value
        <Checkbox
          id={fieldId}
          label={name}
          title={description || name}
          description={description}
          isChecked={!!(value || defaultValue)}
          onChange={(_event, checked) => onChange(name, checked)}
        />
      );
    } else {
      return (
        <TextInput
          id={fieldId}
          value={value || defaultValue || ''}
          onChange={(_event, newValue) => onChange(name, newValue)}
          isRequired={isRequired}
        />
      );
    }
  };

  let label = name;
  // Don't show labelInfo for array types because we already render it
  // as a FormSelect dropdown and this is extra noise. Note that since
  // right now we are not attempting to interpret task parameter types
  // due to its complexity (e.g. use of Variant with multiple types),
  // task parameter Enum types are not handled as arrays and so labelInfo
  // will always show for those types.
  let labelInfo = Array.isArray(type) ? null : type;
  // For boolean types, don't use label or labelInfo on the FormGroup
  // since the Checkbox component already has a label and its boolean-ness
  // is obvious.
  if (type === 'boolean' || type === 'Optional[Boolean]') {
    label = null;
    labelInfo = null;
  }
  return (
    <FormGroup
      label={label}
      labelInfo={labelInfo}
      isRequired={isRequired}
      fieldId={fieldId}
      className="pf-v5-u-mb-lg"
    >
      <FormHelperText>{description}</FormHelperText>
      {renderInput()}
    </FormGroup>
  );
};

export default ParameterField;
