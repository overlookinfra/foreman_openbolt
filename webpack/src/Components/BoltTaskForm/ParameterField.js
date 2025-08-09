import React from 'react';
import PropTypes from 'prop-types';
import {
  FormGroup,
  FormHelperText,
  FormSelect,
  FormSelectOption,
  TextInput,
} from '@patternfly/react-core';

// TODO: The "required" attribute is being ignored and you can still submit
// the form to run a task without filling in required parameters. Need to figure
// out why the browser isn't enforcing this.
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
  const isRequired =
    showRequired &&
    !type
      ?.toString()
      .toLowerCase()
      .startsWith('optional[');
  const fieldId = `param_${name}`;

  const renderInput = () => {
    if (Array.isArray(type)) {
      return (
        <FormGroup
          label={name}
          isRequired={isRequired}
          fieldId={fieldId}
          className="pf-v5-u-mb-lg"
        >
          {description && <FormHelperText>{description}</FormHelperText>}
          <FormSelect
            id={fieldId}
            title={description || name}
            value={value || defaultValue || ''}
            onChange={(_event, val) => onChange(name, val)}
            isRequired={isRequired}
            className="without_select2"
          >
            {type.map(option => (
              <FormSelectOption key={option} value={option} label={option} />
            ))}
          </FormSelect>
        </FormGroup>
      );
    } else if (type === 'boolean' || type === 'Optional[Boolean]') {
      // PatternFly's Checkbox looks like absolute hot garbage next to
      // other FormGroup inputs. This is gross, but it looks better I guess.
      // Should the checkboxes be on the left so they align? But this then
      // misaligns the labels. Ugh.
      return (
        <div className="pf-v5-u-mb-lg">
          <div className="pf-v5-u-display-flex pf-v5-u-align-items-center pf-v5-u-mb-sm">
            <label
              htmlFor={fieldId}
              className="pf-v5-c-form__label pf-v5-u-mr-md"
            >
              <span className="pf-v5-c-form__label-text">{name}</span>
            </label>
            <input
              type="checkbox"
              id={fieldId}
              checked={!!(value || defaultValue)}
              onChange={event => onChange(name, event.target.checked)}
            />
          </div>
          {description && (
            <div className="pf-v5-c-form__helper-text">{description}</div>
          )}
        </div>
      );
    }
    return (
      <FormGroup
        label={name}
        labelInfo={type}
        isRequired={isRequired}
        fieldId={fieldId}
        className="pf-v5-u-mb-lg"
      >
        {description && <FormHelperText>{description}</FormHelperText>}
        <TextInput
          id={fieldId}
          value={value || defaultValue || ''}
          onChange={(_event, newValue) => onChange(name, newValue)}
          isRequired={isRequired}
        />
      </FormGroup>
    );
  };

  return renderInput();
};

ParameterField.propTypes = {
  name: PropTypes.string.isRequired,
  metadata: PropTypes.object.isRequired,
  value: PropTypes.any.isRequired,
  showRequired: PropTypes.bool.isRequired,
  onChange: PropTypes.func.isRequired,
};

export default ParameterField;
