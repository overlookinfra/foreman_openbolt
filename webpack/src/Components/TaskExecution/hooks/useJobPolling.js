/* eslint-disable no-await-in-loop */
import { useState, useEffect, useRef } from 'react';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import { extractErrorMessage } from '../../common/helpers';
import {
  STATUS,
  COMPLETED_STATUSES,
  POLLING_CONFIG,
  ROUTES,
} from '../../common/constants';

const useJobPolling = jobId => {
  const [status, setStatus] = useState(STATUS.PENDING);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [isPolling, setIsPolling] = useState(false);
  const [submittedAt, setSubmittedAt] = useState(null);
  const [completedAt, setCompletedAt] = useState(null);
  const [taskName, setTaskName] = useState(null);
  const [taskDescription, setTaskDescription] = useState(null);
  const [taskParameters, setTaskParameters] = useState({});
  const [targets, setTargets] = useState([]);
  const [smartProxy, setSmartProxy] = useState(null);
  const metadataLoaded = useRef(false);

  // There are a bunch of checks of 'cancelled' here so that if the
  // user navigates away while polling, we don't keep trying to update state.
  useEffect(() => {
    // Have to return undefined since we are returning a cleanup function
    // otherwise and React wants all code paths to return something.
    if (!jobId) return undefined;

    let cancelled = false;

    const poll = async () => {
      setIsPolling(true);

      while (!cancelled) {
        try {
          const { data: statusData } = await API.get(
            `${ROUTES.API.JOB_STATUS}?job_id=${jobId}`
          );

          if (cancelled) break;

          const jobStatus = statusData?.status;
          if (!jobStatus) {
            throw new Error(__('No job status returned'));
          }

          setStatus(jobStatus);
          setCompletedAt(statusData.completed_at || null);

          // Task metadata only needs to be set once since it never changes
          if (!metadataLoaded.current) {
            setSubmittedAt(statusData.submitted_at || null);
            setTaskName(statusData.task_name || null);
            setTaskDescription(statusData.task_description || null);
            setTaskParameters(statusData.task_parameters || {});
            setTargets(statusData.targets || []);
            setSmartProxy(statusData.smart_proxy || null);
            metadataLoaded.current = true;
          }

          // If job is complete, fetch results and break
          if (COMPLETED_STATUSES.includes(jobStatus)) {
            if (jobStatus === STATUS.INVALID) break;
            try {
              const { data: resultData } = await API.get(
                `${ROUTES.API.JOB_RESULT}?job_id=${jobId}`
              );

              if (!cancelled && resultData) {
                setResult({
                  command: resultData.command || '',
                  result: resultData.value,
                  log: resultData.log || '',
                });
              }
            } catch (resultError) {
              // Don't fail the whole thing if result fetch fails
              if (!cancelled) {
                setError(
                  sprintf(
                    __('Failed to fetch job result: %s'),
                    extractErrorMessage(resultError)
                  )
                );
                setResult({ result: null, log: '' });
              }
            }
            break;
          }

          // Wait before next poll
          if (!cancelled) {
            await new Promise(resolve =>
              setTimeout(resolve, POLLING_CONFIG.INTERVAL)
            );
          }
        } catch (err) {
          if (!cancelled) {
            setError(
              sprintf(
                __('Failed to fetch job status: %s'),
                extractErrorMessage(err)
              )
            );
          }
          break;
        }
      }

      if (!cancelled) {
        setIsPolling(false);
      }
    };

    poll();

    return () => {
      cancelled = true;
      setIsPolling(false);
    };
  }, [jobId]);

  return {
    status,
    result,
    error,
    isPolling,
    submittedAt,
    completedAt,
    taskName,
    taskDescription,
    taskParameters,
    targets,
    smartProxy,
  };
};

export default useJobPolling;
