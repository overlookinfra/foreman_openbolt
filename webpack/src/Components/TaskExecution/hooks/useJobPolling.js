/* eslint-disable no-await-in-loop */
import { useState, useEffect } from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import {
  STATUS,
  COMPLETED_STATUSES,
  POLLING_CONFIG,
  ROUTES,
} from '../../common/constants';

/**
 * Custom hook for polling job status
 * @param {string} proxyId - Smart Proxy ID
 * @param {string} jobId - Job ID to poll
 * @returns {Object} - { status, result, error, isPolling }
 */
const useJobPolling = (proxyId, jobId) => {
  const [status, setStatus] = useState(STATUS.PENDING);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [isPolling, setIsPolling] = useState(false);
  const [pollCount, setPollCount] = useState(0);

  // There are a bunch of checks of 'cancelled' here so that if the
  // user navigates away while polling, we don't keep trying to update state.
  useEffect(() => {
    // Have to return undefined since we are returning a cleanup function
    // otherwise and React wants all code paths to return something.
    if (!proxyId || !jobId) return undefined;

    let cancelled = false;

    const poll = async () => {
      setIsPolling(true);

      while (!cancelled) {
        try {
          const { data: statusData, status: statusCode } = await API.get(
            `${ROUTES.API.JOB_STATUS}?proxy_id=${proxyId}&job_id=${jobId}`
          );

          if (cancelled) break;

          if (statusCode !== 200) {
            const errorMsg = statusData
              ? statusData.error || JSON.stringify(statusData)
              : 'Unknown error';
            throw new Error(`HTTP ${statusCode} - ${errorMsg}`);
          }

          const jobStatus = statusData?.status;
          if (!jobStatus) {
            throw new Error('No job status returned');
          }

          setStatus(jobStatus);
          setPollCount(prev => prev + 1);

          // If job is complete, fetch results and break
          if (COMPLETED_STATUSES.includes(jobStatus)) {
            if (jobStatus === STATUS.INVALID) break;
            try {
              const { data: resultData, status: resultCode } = await API.get(
                `${ROUTES.API.JOB_RESULT}?proxy_id=${proxyId}&job_id=${jobId}`
              );

              if (!cancelled && resultCode === 200 && resultData) {
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
                  __('Failed to fetch job result: ') +
                    (resultError.message || 'Unknown error')
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
              __('Failed to fetch job status: ') +
                (err.message || 'Unknown error')
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
  }, [proxyId, jobId]);

  return {
    status,
    result,
    error,
    isPolling,
    pollCount,
  };
};

export default useJobPolling;
