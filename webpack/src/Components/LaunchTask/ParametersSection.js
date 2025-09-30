import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { FormGroup } from '@patternfly/react-core';
import ParameterField from './ParameterField';
import FieldTable from './FieldTable';
import EmptyContent from './EmptyContent';

const ParametersSection = ({
  selectedTask,
  taskMetadata,
  taskParameters,
  onParameterChange,
}) => {
  const hasParameters =
    selectedTask &&
    taskMetadata[selectedTask]?.parameters &&
    Object.keys(taskMetadata[selectedTask].parameters).length > 0;

  const render = () => {
    if (!selectedTask)
      return <EmptyContent title={__('Select a task to see parameters')} />;
    if (!hasParameters)
      return <EmptyContent title={__('This task has no parameters')} />;
    const entries = Object.entries(taskMetadata[selectedTask].parameters);
    const rows = entries.map(([paramName, metadata]) => {
      const isRequired = !metadata.type
        ?.toString()
        .toLowerCase()
        .startsWith('optional');
      return {
        key: paramName,
        name: paramName,
        required: isRequired,
        valueCell: (
          <ParameterField
            name={paramName}
            metadata={metadata}
            value={taskParameters[paramName]}
            onChange={onParameterChange}
            isRequired={isRequired}
          />
        ),
        type: metadata.type,
        description: metadata.description,
      };
    });

    return <FieldTable rows={rows} />;
  };

  return (
    <FormGroup label={__('Parameters')} fieldId="task-parameters">
      {render()}
    </FormGroup>
  );
};

ParametersSection.propTypes = {
  selectedTask: PropTypes.string.isRequired,
  taskMetadata: PropTypes.object.isRequired,
  taskParameters: PropTypes.object.isRequired,
  onParameterChange: PropTypes.func.isRequired,
};

export default ParametersSection;
