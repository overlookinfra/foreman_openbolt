import { useState, useCallback } from 'react';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import { ROUTES } from '../../common/constants';
import { useShowMessage, extractErrorMessage } from '../../common/helpers';

export const useTasksData = () => {
  const showMessage = useShowMessage();
  const [taskMetadata, setTaskMetadata] = useState({});
  const [selectedTask, setSelectedTask] = useState('');
  const [taskParameters, setTaskParameters] = useState({});
  const [isLoadingTasks, setIsLoadingTasks] = useState(false);

  const fetchTasks = useCallback(
    async (proxyId, forceReload = false) => {
      if (!proxyId) return null;

      setIsLoadingTasks(true);
      setTaskMetadata({});
      setSelectedTask('');
      setTaskParameters({});

      try {
        let data;
        if (forceReload) {
          ({ data } = await API.post(
            `${ROUTES.API.RELOAD_TASKS}?smart_proxy_id=${proxyId}`
          ));
        } else {
          ({ data } = await API.get(
            `${ROUTES.API.FETCH_TASKS}?smart_proxy_id=${proxyId}`
          ));
        }

        setTaskMetadata(data || {});

        if (forceReload) {
          showMessage(__('Tasks reloaded successfully'), 'success');
        }

        return data;
      } catch (error) {
        showMessage(
          sprintf(__('Failed to load tasks: %s'), extractErrorMessage(error))
        );
        return null;
      } finally {
        setIsLoadingTasks(false);
      }
    },
    [showMessage]
  );

  return {
    taskMetadata,
    selectedTask,
    setSelectedTask,
    taskParameters,
    setTaskParameters,
    isLoadingTasks,
    fetchTasks,
  };
};
