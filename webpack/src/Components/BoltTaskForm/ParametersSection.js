import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import {
  FormGroup,
  Card,
  CardBody,
  EmptyState,
  EmptyStateIcon,
  EmptyStateHeader
} from '@patternfly/react-core';
import { InfoCircleIcon } from '@patternfly/react-icons';
import ParameterField from './ParameterField';

const ParametersSection = ({ 
  selectedTask, 
  taskMetadata, 
  taskParameters, 
  onParameterChange 
}) => {
  const hasParameters = selectedTask &&
    taskMetadata[selectedTask]?.parameters &&
    Object.keys(taskMetadata[selectedTask].parameters).length > 0;

  return (
    <FormGroup
      label={__('Parameters')}
      fieldId="task-parameters"
    >
      <Card>
        <CardBody>
          {!selectedTask ? (
            <EmptyState>
              <EmptyStateHeader 
                titleText={__('Select a task to see parameters')}
                icon={<EmptyStateIcon icon={InfoCircleIcon} />}
                headingLevel="h4"
              />
            </EmptyState>
          ) : hasParameters ? (
            Object.entries(taskMetadata[selectedTask].parameters).map(([paramName, metadata]) => (
              <ParameterField
                key={paramName}
                name={paramName}
                metadata={metadata}
                value={taskParameters[paramName]}
                onChange={onParameterChange}
                showRequired={true}
              />
            ))
          ) : (
            <EmptyState>
              <EmptyStateHeader 
                titleText={__('This task has no parameters')}
                icon={<EmptyStateIcon icon={InfoCircleIcon} />}
                headingLevel="h4"
              />
            </EmptyState>
          )}
        </CardBody>
      </Card>
    </FormGroup>
  );
};

export default ParametersSection;
