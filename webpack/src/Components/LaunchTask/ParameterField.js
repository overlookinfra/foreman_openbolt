import React from 'react';
import PropTypes from 'prop-types';
import {
  Checkbox,
  FormSelect,
  FormSelectOption,
  TextInput,
} from '@patternfly/react-core';
import { ENCRYPTED_DEFAULT_PLACEHOLDER } from '../common/constants';

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
 * Example OpenBolt Options parameter metadata from the proxy (see OPENBOLT_OPTIONS in main.rb of the proxy code):
 * {
 *   "noop": {
 *     "type": "boolean",
 *     "transport": ["ssh", "winrm"],
 *     "sensitive": false
 *   },
 *   "user": {
 *     "type": "string",
 *     "transport": ["ssh", "winrm"],
 *     "sensitive": false
 *   },
 *   "transport": {
 *     "type": ["ssh", "winrm"],
 *     "transport": ["ssh", "winrm"],
 *     "sensitive": false,
 *     "default": "ssh"
 *   },
 *   "password": {
 *     "type": "string",
 *     "transport": ["ssh", "winrm"],
 *     "sensitive": true
 *   }
 * }
 */

// TODO: The "required" attribute is being ignored and you can still submit
// the form to run a task without filling in required parameters. Need to figure
// out why the browser isn't enforcing this.
const ParameterField = ({
  name,
  metadata,
  value,
  onChange,
  isRequired = false,
}) => {
  const {
    type,
    sensitive,
    default: defaultValue = null,
    description = null,
  } = metadata;

  const fieldId = `param_${name}`;
  const hasEncryptedDefault = defaultValue === ENCRYPTED_DEFAULT_PLACEHOLDER;

  // Enums (arrays of strings) are rendered as dropdowns. We don't show
  // the type label for these since the options are self-evident. Also
  // no encrypted values.
  if (Array.isArray(type)) {
    return (
      <FormSelect
        id={fieldId}
        aria-label={description || name}
        title={description || name}
        value={value ?? defaultValue ?? ''}
        onChange={(_event, val) => onChange(name, val)}
        isRequired={isRequired}
        className="without_select2"
      >
        {type.map(option => (
          <FormSelectOption key={option} value={option} label={option} />
        ))}
      </FormSelect>
    );
  }

  // Booleans are rendered as checkboxes. No type label or encrypted values.
  // PatternFly's Checkbox looks like absolute hot garbage by default. This
  // inlines it with the label to make it look less awful.
  if (type === 'boolean' || type === 'Optional[Boolean]') {
    return (
      <Checkbox
        id={fieldId}
        isChecked={!!(value ?? defaultValue)}
        onChange={(_event, checked) => onChange(name, checked)}
        aria-label={name}
      />
    );
  }

  // Everything else is a text input of some kind, at least for now.
  // These can have encrypted defaults. When the user hasn't input
  // a new value, and we have an encrypted default, we don't want to
  // set the default value and instead set an empty string. We inject
  // the actual default value in the controller.
  const isBlank = v => v === undefined || v === '';
  const fallback = hasEncryptedDefault ? '' : defaultValue ?? '';
  const resolvedValue = isBlank(value) ? fallback : value;

  return (
    <TextInput
      id={fieldId}
      type={sensitive ? 'password' : 'text'}
      value={resolvedValue}
      onChange={(_event, newValue) => onChange(name, newValue)}
      isRequired={isRequired && !hasEncryptedDefault}
    />
  );
};

ParameterField.propTypes = {
  name: PropTypes.string.isRequired,
  metadata: PropTypes.object.isRequired,
  value: PropTypes.any,
  onChange: PropTypes.func.isRequired,
  isRequired: PropTypes.bool,
};

ParameterField.defaultProps = {
  value: undefined,
  isRequired: false,
};

export default ParameterField;
