// TODO: More a11y tags
import React, { useState, useCallback } from 'react';
import { useHistory } from 'react-router-dom';
import { translate as __ } from 'foremanReact/common/I18n';

import { API } from 'foremanReact/redux/API';
import { Button, Form, FormGroup } from '@patternfly/react-core';

import { ROUTES } from '../common/constants';
import SmartProxySelect from './SmartProxySelect';
import TaskSelect from './TaskSelect';
import ParametersSection from './ParametersSection';
import OpenBoltOptionsSection from './OpenBoltOptionsSection';
import HostSelector from './HostSelector';
import { useSmartProxies } from './hooks/useSmartProxies';
import { useTasksData } from './hooks/useTasksData';
import { useOpenBoltOptions } from './hooks/useOpenBoltOptions';
import { useShowMessage } from '../common/helpers';

const LaunchTask = () => {
  const history = useHistory();
  const showMessage = useShowMessage();

  /* States */
  const [selectedProxy, setSelectedProxy] = useState('');
  const [targets, setTargets] = useState([]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  /* Custom hooks for data fetching */
  // The strategy here is to manage all data fetching and state within
  // these custom hooks. The rest of this component handles orchestration
  // of that data.
  const { smartProxies, isLoadingProxies } = useSmartProxies();
  const {
    taskMetadata,
    selectedTask,
    setSelectedTask,
    taskParameters,
    setTaskParameters,
    isLoadingTasks,
    fetchTasks,
  } = useTasksData();
  const {
    openBoltOptionsMetadata,
    openBoltOptions,
    setOpenBoltOptions,
    isLoadingOptions,
    fetchOpenBoltOptions,
  } = useOpenBoltOptions();

  /* Event handlers */
  const handleProxyChange = useCallback(
    (_event, value) => {
      setSelectedProxy(value);
      if (value) {
        fetchTasks(value);
        fetchOpenBoltOptions(value);
      } else {
        setSelectedTask('');
        setTaskParameters({});
        setOpenBoltOptions({});
      }
    },
    [
      fetchTasks,
      fetchOpenBoltOptions,
      setSelectedTask,
      setTaskParameters,
      setOpenBoltOptions,
    ]
  );

  const handleTaskChange = useCallback(
    (_event, value) => {
      setSelectedTask(value);
      // TODO: Do we want to set boolean to default false here when
      // a default is not provided?
      if (value && taskMetadata[value]) {
        const defaults = {};
        const params = taskMetadata[value].parameters || {};
        Object.entries(params).forEach(([paramName, paramMeta]) => {
          if (paramMeta.default !== undefined) {
            defaults[paramName] = paramMeta.default;
          } else if (
            ['boolean', 'optional[boolean]'].includes(
              paramMeta.type.toLowerCase()
            )
          ) {
            defaults[paramName] = false;
          }
        });
        setTaskParameters(defaults);
      } else {
        setTaskParameters({});
      }
    },
    [setSelectedTask, setTaskParameters, taskMetadata]
  );

  const handleParameterChange = useCallback(
    (paramName, value) => {
      setTaskParameters(prev => ({ ...prev, [paramName]: value }));
    },
    [setTaskParameters]
  );

  const handleOptionChange = useCallback(
    (optionName, value) => {
      setOpenBoltOptions(prev => ({ ...prev, [optionName]: value }));
    },
    [setOpenBoltOptions]
  );

  const handleReloadTasks = useCallback(() => {
    if (selectedProxy) {
      fetchTasks(selectedProxy, true);
    }
  }, [selectedProxy, fetchTasks]);

  const handleTargetsChange = useCallback(
    targetArray => {
      setTargets(targetArray);
    },
    [setTargets]
  );

  const handleSubmit = useCallback(
    async e => {
      e.preventDefault();

      if (!selectedProxy || !selectedTask || targets.length === 0) {
        showMessage(__('Please select a proxy, task, and enter targets.'));
        return;
      }

      setIsSubmitting(true);

      try {
        const { transport } = openBoltOptions;
        const visibleOptions = {};
        Object.entries(openBoltOptionsMetadata).forEach(
          ([optionName, metadata]) => {
            const isVisible =
              optionName === 'transport' ||
              !metadata.transport ||
              metadata.transport.includes(transport);
            if (isVisible && openBoltOptions[optionName] !== undefined) {
              visibleOptions[optionName] = openBoltOptions[optionName];
            }
          }
        );

        const body = {
          proxy_id: selectedProxy,
          task_name: selectedTask,
          targets: targets.join(','),
          params: taskParameters,
          options: visibleOptions,
        };

        const { data, status } = await API.post(ROUTES.API.LAUNCH_TASK, body);

        // TODO: On non-200, the post above automatically throws an exception, so
        // figure out how to handle it instead to extract the message in the
        // response body.
        if (status !== 200) {
          const error = data
            ? data.error || JSON.stringify(data)
            : 'Unknown error';
          throw new Error(`HTTP ${status} - ${error}`);
        }

        const selectedProxyData = smartProxies.find(
          p => p.id.toString() === selectedProxy.toString()
        );

        history.push({
          pathname: ROUTES.PAGES.TASK_EXECUTION,
          search: new URLSearchParams({
            proxy_id: selectedProxy,
            job_id: data.job_id,
            proxy_name: selectedProxyData?.name || 'Unknown',
            target_count: targets.length.toString(),
          }).toString(),
        });
      } catch (error) {
        const errorMessage =
          error.response?.data?.error ||
          error.message ||
          __('Unknown error occurred');
        showMessage(__('Failed to launch task: ') + errorMessage);
      } finally {
        setIsSubmitting(false);
      }
    },
    [
      selectedProxy,
      selectedTask,
      targets,
      taskParameters,
      openBoltOptions,
      openBoltOptionsMetadata,
      smartProxies,
      history,
      showMessage,
    ]
  );

  /* Rendering */
  const isFormValid =
    selectedProxy &&
    selectedTask &&
    targets.length > 0 &&
    !isLoadingTasks &&
    !isLoadingOptions &&
    !isSubmitting;

  return (
    <div className="openbolt-task-form">
      <Form onSubmit={handleSubmit}>
        <SmartProxySelect
          smartProxies={smartProxies}
          selectedProxy={selectedProxy}
          onProxyChange={handleProxyChange}
          isLoading={isLoadingProxies}
        />

        <HostSelector
          onChange={handleTargetsChange}
          targetCount={targets.length}
        />

        <TaskSelect
          taskNames={Object.keys(taskMetadata || {})}
          selectedTask={selectedTask}
          onTaskChange={handleTaskChange}
          onReloadTasks={handleReloadTasks}
          isLoading={isLoadingTasks}
          isDisabled={!selectedProxy}
        />

        <ParametersSection
          selectedTask={selectedTask}
          taskMetadata={taskMetadata}
          taskParameters={taskParameters}
          onParameterChange={handleParameterChange}
        />

        <OpenBoltOptionsSection
          selectedProxy={selectedProxy}
          openBoltOptionsMetadata={openBoltOptionsMetadata}
          openBoltOptions={openBoltOptions}
          onOptionChange={handleOptionChange}
          isLoading={isLoadingOptions}
        />

        <FormGroup>
          <Button
            type="submit"
            variant="primary"
            isDisabled={!isFormValid}
            isLoading={isSubmitting}
          >
            {__('🚀 Launch Task')}
          </Button>
        </FormGroup>
      </Form>
    </div>
  );
};

export default LaunchTask;
