import React, { useEffect } from 'react';
import { useLocation, useHistory } from 'react-router-dom';
import { translate as __ } from 'foremanReact/common/I18n';
import { Button, Alert } from '@patternfly/react-core';

import ExecutionDetails from './ExecutionDetails';
import LoadingIndicator from './LoadingIndicator';
import ResultDisplay from './ResultDisplay';
import useJobPolling from './hooks/useJobPolling';
import { COMPLETED_STATUSES, ROUTES } from '../common/constants';
import { useShowMessage } from '../common/helpers';

const TaskExecution = () => {
  const location = useLocation();
  const history = useHistory();
  const showMessage = useShowMessage();

  const params = new URLSearchParams(location.search);
  const proxyId = params.get('proxy_id');
  const jobId = params.get('job_id');
  const proxyName = params.get('proxy_name');
  const targetCount = params.get('target_count');

  const {
    status: jobStatus,
    result: jobData,
    error: pollError,
    isPolling,
    pollCount,
  } = useJobPolling(proxyId, jobId);

  useEffect(() => {
    if (pollError) {
      showMessage(pollError);
    }
  }, [pollError, showMessage]);

  // Redirect if missing required params
  useEffect(() => {
    if (!proxyId || !jobId) {
      showMessage(
        __('Invalid task execution URL - missing required parameters')
      );
      history.push(ROUTES.PAGES.LAUNCH_TASK);
    }
  }, [proxyId, jobId, showMessage, history]);

  // Don't render if missing required params
  if (!proxyId || !jobId) {
    return null;
  }

  const isComplete = COMPLETED_STATUSES.includes(jobStatus);
  const jobResult = jobData?.result;
  const jobLog = jobData?.log;

  return (
    <div className="openbolt-task-execution">
      <Button
        variant="secondary"
        onClick={() => history.push(ROUTES.PAGES.LAUNCH_TASK)}
        className="pf-v5-u-mb-md"
      >
        {__('Run Another Task')}
      </Button>

      <ExecutionDetails
        proxyName={proxyName}
        jobId={jobId}
        jobStatus={jobStatus}
        pollCount={pollCount}
        isPolling={isPolling}
        targetCount={targetCount || 'Unknown'}
      />

      {isPolling && <LoadingIndicator jobStatus={jobStatus} />}

      {!isPolling && jobResult && (
        <ResultDisplay jobResult={jobResult} jobLog={jobLog} />
      )}

      {!isPolling && !jobResult && isComplete && (
        <Alert variant="warning" title={__('No Results')} isInline>
          {__('No results for this task run could be retrieved.')}
        </Alert>
      )}

      {pollError && (
        <Alert variant="danger" title={__('Error')} isInline>
          {pollError}
        </Alert>
      )}
    </div>
  );
};

export default TaskExecution;
