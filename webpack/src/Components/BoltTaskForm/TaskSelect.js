import React from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import {
  FormGroup,
  FormSelect,
  FormSelectOption,
  Button,
  Spinner,
} from '@patternfly/react-core';
import { SyncIcon } from '@patternfly/react-icons';

const TaskSelect = ({
  taskNames,
  selectedTask,
  onTaskChange,
  onReloadTasks,
  isLoading,
  isDisabled,
}) => (
  <FormGroup label={__('Task Name')} fieldId="task-name-input">
    <div className="pf-v5-u-display-flex">
      <FormSelect
        id="task-select"
        title={
          isDisabled
            ? __('You must first select a Smart Proxy')
            : __('Select a task to execute.')
        }
        value={selectedTask}
        onChange={onTaskChange}
        isDisabled={isDisabled || isLoading}
        className="without_select2 pf-v5-u-flex-grow pf-v5-u-mr-sm"
      >
        <FormSelectOption
          key="select-task"
          value=""
          isPlaceholder
          label={isLoading ? __('Loading...') : __('Select Task')}
        />
        {taskNames.map(taskName => (
          <FormSelectOption key={taskName} value={taskName} label={taskName} />
        ))}
      </FormSelect>
      <Button
        variant="secondary"
        onClick={onReloadTasks}
        isDisabled={isDisabled || isLoading}
        icon={isLoading ? <Spinner size="sm" /> : <SyncIcon />}
        title={__('Reload tasks from Bolt. This may take some time.')}
      />
    </div>
  </FormGroup>
);

TaskSelect.propTypes = {
  taskNames: PropTypes.arrayOf(PropTypes.string).isRequired,
  selectedTask: PropTypes.string.isRequired,
  onTaskChange: PropTypes.func.isRequired,
  onReloadTasks: PropTypes.func.isRequired,
  isLoading: PropTypes.bool.isRequired,
  isDisabled: PropTypes.bool.isRequired,
};

export default TaskSelect;
