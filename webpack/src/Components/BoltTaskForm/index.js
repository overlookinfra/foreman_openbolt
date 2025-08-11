// TODO: More a11y tags
import React, { useState, useCallback, useEffect } from 'react';
import { useSelector } from 'react-redux';
import { useHistory } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { translate as __ } from 'foremanReact/common/I18n';

import { API } from 'foremanReact/redux/API';
import {
  Button,
  Form,
  FormGroup,
  FormHelperText,
  TextInput,
  InputGroup,
  InputGroupItem,
} from '@patternfly/react-core';

import { ROUTES, HOST_METHODS } from '../common/constants';
import SmartProxySelect from './SmartProxySelect';
import TaskSelect from './TaskSelect';
import ParametersSection from './ParametersSection';
import BoltOptionsSection from './BoltOptionsSection';
import SelectedChips from './SelectedChips';
import { FilterIcon } from '@patternfly/react-icons';
import SelectField from './SelectField';
import HostSearch from './HostSearch';
import SelectGQL from './SelectGQL';
import SelectAPI from './SelectAPI';
import { selectAPIResponse } from 'foremanReact/redux/API/APISelectors';
import { useSmartProxies } from './hooks/useSmartProxies';
import { useTasksData } from './hooks/useTasksData';
import { useBoltOptions } from './hooks/useBoltOptions';
import { useShowMessage } from '../common/helpers';

const BoltTaskForm = () => {
  const history = useHistory();
  const showMessage = useShowMessage();
  const dispatch = useDispatch();

  /* States */
  const [selectedProxy, setSelectedProxy] = useState('');
  const [targets, setTargets] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [hostMethod, setHostMethod] = useState(HOST_METHODS.HOSTS);
  const [hostsSearchQuery, setHostsSearchQuery] = useState('');
  const [hostsSearchResults, setHostsSearchResults] = useState([]);
  const [selectedHosts, setSelectedHosts] = useState([]);
  const [selectedHostGroups, setSelectedHostGroups] = useState([]);
  const [selectedCollections, setSelectedCollections] = useState([]);
  const [selectedTargets, setSelectedTargets] = useState({
    hosts: [],
    hostCollections: [],
    hostGroups: [],
  });
  const [selectedHostCollections, setSelectedHostCollections] = useState([]);


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

  const setLabel = result => result.displayName || result.name;
  const clearSearch = () => {
    setHostsSearchQuery('');
  };
  const selectHostsResponse = state => selectAPIResponse(state, 'HOSTS_API');
  const selectHostCount = state =>
  selectHostsResponse(state).subtotal || 0;
  const hostCount = useSelector(selectHostCount);
  const [wasFocus, setWasFocus] = useState(false);
  const [errorText, setErrorText] = useState(
    __('Please select at least one host')
  );
  const [isError, setIsError] = useState(false);
  const [hostPreviewOpen, setHostPreviewOpen] = useState(false);

  useEffect(() => {
    if (wasFocus) {
      if (
        selectedTargets.hosts.length === 0 &&
        selectedTargets.hostGroups.length === 0 &&
        hostsSearchQuery.length === 0
      ) {
        setIsError(true);
      } else {
        setIsError(false);
      }
    }
  }, [
    hostMethod,
    hostsSearchQuery.length,
    selectedTargets,
    selectedTargets.hostGroups.length,
    selectedTargets.hosts.length,
    wasFocus,
  ]);
  useEffect(() => {
    debounce(() => {
      dispatch(
        get({
          key: 'HOSTS_API',
          url: '/api/hosts',
          params: {
            search: buildHostQuery(selectedTargets, hostsSearchQuery),
            per_page: 20,
          },
        })
      );
    }, 1500)();
  }, [
    dispatch,
    selectedTargets,
    selectedTargets.hosts,
    selectedTargets.hostGroups,
    hostsSearchQuery,
  ]);

  return (
    <div className="bolt-task-form">
      <Form onSubmit={handleSubmit}>
        <SmartProxySelect
          smartProxies={smartProxies}
          selectedProxy={selectedProxy}
          onProxyChange={handleProxyChange}
          isLoading={isLoadingProxies}
        />
        {hostPreviewOpen && (
        <HostPreviewModal
          isOpen={hostPreviewOpen}
          setIsOpen={setHostPreviewOpen}
          searchQuery={buildHostQuery(selectedTargets, hostsSearchQuery)}
        />
      )}

        <FormGroup fieldId="host_selection" id="host-selection">
          <InputGroup onBlur={() => setWasFocus(true)}>
            <InputGroupItem>
              <SelectField
                isRequired
                className="target-method-select"
                toggleIcon={<FilterIcon />}
                fieldId="host_methods"
                options={Object.values(HOST_METHODS)}
                setValue={val => {
                  setHostMethod(val);
                  if (val === HOST_METHODS.SEARCH_QUERY) {
                    setErrorText(__('Please enter a search query'));
                  }
                  if (val === HOST_METHODS.HOSTS) {
                    setErrorText(__('Please select at least one host'));
                  }
                  if (val === HOST_METHODS.HOST_GROUPS) {
                    setErrorText(__('Please select at least one host group'));
                  }
                }}
                value={hostMethod}
              />
            </InputGroupItem>
            {hostMethod === HOST_METHODS.SEARCH_QUERY && (
              <HostSearch
                setValue={setHostsSearchQuery}
                value={hostsSearchQuery}
              />
            )}
            {hostMethod === HOST_METHODS.HOSTS && (
              <SelectGQL
                selected={selectedHosts}
                setSelected={setSelectedHosts}
                apiKey={HOST_METHODS.HOSTS}
                name="hosts"
                placeholderText={__('Filter by hosts')}
                setLabel={setLabel}
              />
            )}
            {hostMethod === HOST_METHODS.HOST_COLLECTIONS && (
              <SelectAPI
                selected={selectedHostCollections}
                setSelected={setSelectedHostCollections}
                apiKey={HOST_COLLECTIONS}
                name="host collections"
                url="/katello/api/host_collections?per_page=100"
                placeholderText={__('Filter by host collections')}
                setLabel={setLabel}
              />
            )}
            {hostMethod === HOST_METHODS.HOST_GROUPS && (
              <SelectGQL
                selected={selectedHostGroups}
                setSelected={setSelectedHostGroups}
                apiKey={HOST_GROUPS}
                name="host groups"
                placeholderText={__('Filter by host groups')}
                setLabel={setLabel}
              />
            )}
          </InputGroup>
        </FormGroup>
        <SelectedChips
          selectedHosts={selectedHosts}
          setSelectedHosts={setSelectedHosts}
          selectedHostCollections={selectedHostCollections}
          setSelectedHostCollections={setSelectedHostCollections}
          selectedHostGroups={selectedHostGroups}
          setSelectedHostGroups={setSelectedHostGroups}
          hostsSearchQuery={hostsSearchQuery}
          clearSearch={clearSearch}
          setLabel={setLabel}
        />
        <Text ouiaId="host-preview-label">
          {__('Apply to')}{' '}
          <Button
            ouiaId="host-preview-open-button"
            variant="link"
            isInline
            onClick={() => setHostPreviewOpen(true)}
            isDisabled={false}
          >
            {hostCount} {__('hosts')}
          </Button>{' '}
          {isLoadingProxies && <Spinner size="sm" />}
        </Text>

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
