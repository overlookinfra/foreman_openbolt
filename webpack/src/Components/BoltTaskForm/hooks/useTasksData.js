import { useState, useCallback } from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import { ROUTES } from '../../common/constants';

export const useTasksData = (showMessage) => {
  const [taskMetadata, setTaskMetadata] = useState({});
  const [selectedTask, setSelectedTask] = useState('');
  const [taskParameters, setTaskParameters] = useState({});
  const [isLoadingTasks, setIsLoadingTasks] = useState(false);

  const fetchTasks = useCallback(async (proxyId, forceReload = false) => {
    if (!proxyId) return null;
    
    setIsLoadingTasks(true);
    setTaskMetadata({});
    setSelectedTask('');
    setTaskParameters({});

    try {
      const endpoint = forceReload ? ROUTES.API.RELOAD_TASKS : ROUTES.API.FETCH_TASKS;
      const { data, status } = await API.get(`${endpoint}?proxy_id=${proxyId}`);
      
      if (status !== 200) {
        const error = data ? data.error || JSON.stringify(data) : 'Unknown error';
        throw new Error(`HTTP ${status} - ${error}`);
      }
      
      setTaskMetadata(data || {});
      
      // Auto-select first task if available
      const taskNames = Object.keys(data || {});
      if (taskNames.length > 0) {
        setSelectedTask(taskNames[0]);
      }
      
      if (forceReload) {
        showMessage(__('Tasks reloaded successfully'), 'success');
      }
      
      return data;
    } catch (error) {
      showMessage(__('Failed to load tasks: ') + error.message);
      return null;
    } finally {
      setIsLoadingTasks(false);
    }
  }, [showMessage]);

  return {
    taskMetadata,
    selectedTask,
    setSelectedTask,
    taskParameters,
    setTaskParameters,
    isLoadingTasks,
    fetchTasks
  };
};
