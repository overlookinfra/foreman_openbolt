import React, { useState, useEffect, useCallback } from 'react';
import SmartProxySelector from './components/SmartProxySelector/SmartProxySelector';
import TargetsInput from './components/TargetsInput/TargetsInput';
import TaskSelector from './components/TaskSelector/TaskSelector';
import ParameterPanel from './components/ParameterPanel/ParameterPanel';
import BoltOptionsPanel from './components/BoltOptionsPanel/BoltOptionsPanel';
import RunButton from './components/RunButton/RunButton';
import { fetchJson } from '../../utils/fetchJson';

const NewTask = ({ smartProxies, urls, i18n }) => {
  const [selectedProxy, setSelectedProxy] = useState('');
  const [targets, setTargets] = useState('');
  const [taskData, setTaskData] = useState({});
  const [boltOptions, setBoltOptions] = useState({});
  const [loading, setLoading] = useState({ tasks: false, opts: false });
  const [selectedTask, setSelectedTask] = useState('');

  const fetchData = useCallback(async (url, setter, loadingKey) => {
    setLoading(prev => ({ ...prev, [loadingKey]: true }));
    try {
      const response = await fetchJson(`${url}?proxy_id=${encodeURIComponent(selectedProxy)}`);
      setter(response || {});
      return response || {};
    } catch (e) {
      console.error(`Failed to fetch from ${url}`, e);
      setter({}); // Reset on error
      return {};
    } finally {
      setLoading(prev => ({ ...prev, [loadingKey]: false }));
    }
  }, [selectedProxy]);

  const loadTasks = useCallback(async (force = false) => {
    const endpoint = force ? urls.reload : urls.tasks;
    const data = await fetchData(endpoint, setTaskData, 'tasks');
    setSelectedTask(Object.keys(data)[0] || '');
  }, [fetchData, urls]);

  const loadOptions = useCallback(async () => {
    await fetchData(urls.opts, setBoltOptions, 'opts');
  }, [fetchData, urls]);

  useEffect(() => {
    if (selectedProxy) {
      loadTasks();
      loadOptions();
    } else {
      setTaskData({});
      setBoltOptions({});
      setSelectedTask('');
    }
  }, [selectedProxy, loadTasks, loadOptions]);

  const hasProxy = !!selectedProxy;
  const hasTask = !!selectedTask;
  const disabledRun = !hasProxy || !hasTask || loading.tasks || loading.opts;

  return (
    <div className="foreman-bolt-NewTask">
      <SmartProxySelector
        smartProxies={smartProxies}
        value={selectedProxy}
        onChange={setSelectedProxy}
      />
      <TargetsInput value={targets} onChange={setTargets} />
      <TaskSelector
        tasks={Object.keys(taskData)}
        value={selectedTask}
        loading={loading.tasks}
        disabled={!hasProxy}
        onChange={setSelectedTask}
        onReload={() => loadTasks(true)}
      />
      <ParameterPanel
        parameters={taskData[selectedTask]?.parameters || {}}
        loading={loading.tasks}
        i18n={i18n}
        hasProxyAndTask={hasProxy && hasTask}
      />
      <BoltOptionsPanel
        options={boltOptions}
        loading={loading.opts}
        i18n={i18n}
        hasProxy={hasProxy}
      />
      <RunButton disabled={disabledRun} />
    </div>
  );
};

export default NewTask;
