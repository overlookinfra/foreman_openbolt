import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { FormGroup, Card, CardBody } from '@patternfly/react-core';
import ParameterField from './ParameterField';
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
    return Object.entries(
      taskMetadata[selectedTask].parameters
    ).map(([paramName, metadata]) => (
      <ParameterField
        key={paramName}
        name={paramName}
        metadata={metadata}
        value={taskParameters[paramName]}
        onChange={onParameterChange}
        showRequired
      />
    ));
  };

  return (
    <FormGroup label={__('Parameters')} fieldId="task-parameters">
      <Card>
        <CardBody>{render()}</CardBody>
      </Card>
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
