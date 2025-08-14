// TODO: More a11y tags
import React, { useState, useCallback } from 'react';
import { useHistory } from 'react-router-dom';
import { translate as __ } from 'foremanReact/common/I18n';

import { API } from 'foremanReact/redux/API';
import {
  Button,
  Form,
  FormGroup,
  FormHelperText,
  TextInput,
} from '@patternfly/react-core';

import { ROUTES } from '../common/constants';
import SmartProxySelect from './SmartProxySelect';
import TaskSelect from './TaskSelect';
import ParametersSection from './ParametersSection';
import BoltOptionsSection from './BoltOptionsSection';
import { useSmartProxies } from './hooks/useSmartProxies';
import { useTasksData } from './hooks/useTasksData';
import { useBoltOptions } from './hooks/useBoltOptions';
import { useShowMessage } from '../common/helpers';
import HostSelector2 from './HostSelector2';

const BoltTaskForm = () => {
  const history = useHistory();
  const showMessage = useShowMessage();

  /* States */
  const [selectedProxy, setSelectedProxy] = useState('');
  const [targets, setTargets] = useState('');
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
    boltOptionsMetadata,
    boltOptions,
    setBoltOptions,
    isLoadingOptions,
    fetchBoltOptions,
  } = useBoltOptions();

  /* Event handlers */
  const handleProxyChange = useCallback(
    (_event, value) => {
      setSelectedProxy(value);
      if (value) {
        fetchTasks(value);
        fetchBoltOptions(value);
      } else {
        setSelectedTask('');
        setTaskParameters({});
        setBoltOptions({});
      }
    },
    [
      fetchTasks,
      fetchBoltOptions,
      setSelectedTask,
      setTaskParameters,
      setBoltOptions,
    ]
  );

  const handleTaskChange = useCallback(
    (_event, value) => {
      setSelectedTask(value);
      // TODO: Do we want to set boolean to default false here when
      // a default is not provided?
      const defaults = {};
      Object.entries(taskMetadata[value].parameters).forEach(
        ([paramName, paramMeta]) => {
          if (paramMeta.default !== undefined) {
            defaults[paramName] = paramMeta.default;
          } else if (
            ['boolean', 'optional[boolean]'].includes(
              paramMeta.type.toLowerCase()
            )
          ) {
            defaults[paramName] = false;
          }
        }
      );
      setTaskParameters(defaults);
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
      setBoltOptions(prev => ({ ...prev, [optionName]: value }));
    },
    [setBoltOptions]
  );

  const handleReloadTasks = useCallback(() => {
    if (selectedProxy) {
      fetchTasks(selectedProxy, true);
    }
  }, [selectedProxy, fetchTasks]);

  const handleTargetsChange = useCallback((value) => {
    setTargets(value);
    console.log('Targets:', value);
  }, [setTargets]);

  const handleSubmit = async e => {
    e.preventDefault();

    if (!selectedProxy || !selectedTask || !targets.trim()) {
      showMessage(__('Please select a proxy, task, and enter targets.'));
      return;
    }

    setIsSubmitting(true);

    try {
      const body = {
        proxy_id: selectedProxy,
        task_name: selectedTask,
        targets: targets.trim(),
        params: taskParameters,
        options: boltOptions,
      };

      const { data, status } = await API.post(ROUTES.API.EXECUTE_TASK, body);

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
      const proxyName = selectedProxyData?.name || 'Unknown';

      history.push({
        pathname: ROUTES.PAGES.TASK_EXECUTION,
        search: new URLSearchParams({
          proxy_id: selectedProxy,
          job_id: data.job_id,
          proxy_name: proxyName,
          target_count: targets.split(',').length,
        }).toString(),
      });
    } catch (error) {
      showMessage(__('Failed to execute task: ') + error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  /* Rendering */
  const isFormValid =
    selectedProxy &&
    selectedTask &&
    targets.trim() &&
    !isLoadingTasks &&
    !isLoadingOptions &&
    !isSubmitting;

  return (
    <div className="bolt-task-form">
      <Form onSubmit={handleSubmit}>
        <SmartProxySelect
          smartProxies={smartProxies}
          selectedProxy={selectedProxy}
          onProxyChange={handleProxyChange}
          isLoading={isLoadingProxies}
        />

        <HostSelector2
          onChange={handleTargetsChange}
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

        <BoltOptionsSection
          selectedProxy={selectedProxy}
          boltOptionsMetadata={boltOptionsMetadata}
          boltOptions={boltOptions}
          onOptionChange={handleOptionChange}
          isLoading={isLoadingOptions}
        />

        <FormGroup>
          <Button
            type="submit"
            variant="primary"
            isAriaDisabled={!isFormValid}
            isDisabled={!isFormValid}
            isLoading={isSubmitting}
          >
            {__('Run Task')}
          </Button>
        </FormGroup>
      </Form>
    </div>
  );
};

export default BoltTaskForm;
