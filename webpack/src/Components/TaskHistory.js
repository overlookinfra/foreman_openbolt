import React, { useState, useEffect } from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import {
  Label,
  Pagination,
  EmptyState,
  EmptyStateIcon,
  EmptyStateHeader,
  EmptyStateBody,
  Spinner,
  Bullseye,
} from '@patternfly/react-core';
import { Table, Thead, Tbody, Tr, Th, Td } from '@patternfly/react-table';
import {
  CheckCircleIcon,
  ExclamationCircleIcon,
  ExternalLinkAltIcon,
  InProgressIcon,
  OutlinedClockIcon,
  CubesIcon,
} from '@patternfly/react-icons';
import { ROUTES, STATUS } from './common/constants';
import { useShowMessage } from './common/helpers';

const getStatusLabel = status => {
  const configs = {
    [STATUS.SUCCESS]: { color: 'green', icon: <CheckCircleIcon /> },
    [STATUS.FAILURE]: { color: 'red', icon: <ExclamationCircleIcon /> },
    [STATUS.EXCEPTION]: { color: 'orange', icon: <ExclamationCircleIcon /> },
    [STATUS.INVALID]: { color: 'yellow', icon: <ExclamationCircleIcon /> },
    [STATUS.RUNNING]: { color: 'blue', icon: <InProgressIcon /> },
    [STATUS.PENDING]: { color: 'blue', icon: <OutlinedClockIcon /> },
  };

  const config = configs[status] || { color: 'grey', icon: <CubesIcon /> };
  return (
    <Label color={config.color} icon={config.icon}>
      {status}
    </Label>
  );
};

const formatDuration = duration => {
  if (!duration) return '-';
  const seconds = Math.round(duration);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  return `${minutes}m ${remainingSeconds}s`;
};

const formatDate = dateString => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleString();
};

const TaskHistory = () => {
  const [taskHistory, setTaskHistory] = useState([]);
  const [isLoadingTaskHistory, setIsLoadingTaskHistory] = useState(true);
  const [page, setPage] = useState(1);
  const [perPage, setPerPage] = useState(20);
  const [total, setTotal] = useState(0);
  const showMessage = useShowMessage();

  useEffect(() => {
    let cancelled = false;

    const fetchTaskHistory = async () => {
      if (cancelled) return;
      setIsLoadingTaskHistory(true);

      try {
        const { data, status } = await API.get(
          `${ROUTES.API.TASK_HISTORY}?page=${page}&per_page=${perPage}`
        );

        if (!cancelled && status === 200 && data) {
          setTaskHistory(data.results || []);
          setTotal(data.total || 0);
        }
      } catch (error) {
        if (!cancelled)
          showMessage(__('Failed to load task history: ') + error.message);
      } finally {
        if (!cancelled) setIsLoadingTaskHistory(false);
      }
    };

    fetchTaskHistory();

    return () => {
      cancelled = true;
    };
  }, [page, perPage, showMessage]);

  const spinner = () => (
    <Bullseye>
      <Spinner size="xl" />
    </Bullseye>
  );

  const noJobs = () => (
    <EmptyState>
      <EmptyStateHeader
        titleText={__('No task history found')}
        icon={<EmptyStateIcon icon={CubesIcon} />}
        headingLevel="h2"
      />
      <EmptyStateBody>
        {__('Run an OpenBolt task to see it appear here.')}
      </EmptyStateBody>
    </EmptyState>
  );

  const jobTable = () => (
    <>
      <Table
        aria-label="Task history table"
        borders
        isStriped
        isStickyHeader
        variant="compact"
      >
        <Thead>
          <Tr>
            <Th modifier="wrap">{__('Task Name')}</Th>
            <Th modifier="wrap">{__('Status')}</Th>
            <Th modifier="wrap">{__('Targets')}</Th>
            <Th modifier="wrap">{__('Started')}</Th>
            <Th modifier="wrap">{__('Completed')}</Th>
            <Th modifier="wrap">{__('Duration')}</Th>
            <Th modifier="wrap">{__('Details')}</Th>
          </Tr>
        </Thead>
        <Tbody>
          {taskHistory.map(job => (
            <Tr key={job.job_id}>
              <Td hasLeftBorder hasRightBorder>
                {job.task_name || 'unknown'}
              </Td>
              <Td hasLeftBorder hasRightBorder>
                {getStatusLabel(job.status)}
              </Td>
              <Td hasLeftBorder hasRightBorder>
                {job.target_count || 'unknown'}
              </Td>
              <Td hasLeftBorder hasRightBorder>
                {formatDate(job.submitted_at)}
              </Td>
              <Td hasLeftBorder hasRightBorder>
                {job.completed_at ? formatDate(job.completed_at) : ''}
              </Td>
              <Td hasLeftBorder hasRightBorder>
                {formatDuration(job.duration)}
              </Td>
              <Td hasLeftBorder hasRightBorder>
                <a
                  href={`${ROUTES.PAGES.TASK_EXECUTION}?proxy_id=${
                    job.smart_proxy.id
                  }&job_id=${job.job_id}&proxy_name=${encodeURIComponent(
                    job.smart_proxy.name
                  )}&target_count=${job.target_count}`}
                  aria-label={__('View Details')}
                  title={__('View Details')}
                >
                  <ExternalLinkAltIcon />
                </a>
              </Td>
            </Tr>
          ))}
        </Tbody>
      </Table>

      <Pagination
        itemCount={total}
        perPage={perPage}
        page={page}
        onSetPage={(_event, newPage) => setPage(newPage)}
        onPerPageSelect={(_event, newPerPage) => {
          setPerPage(newPerPage);
          setPage(1);
        }}
      />
    </>
  );

  return (
    <div className="task-history">
      {isLoadingTaskHistory && spinner()}
      {!isLoadingTaskHistory && taskHistory.length === 0 && noJobs()}
      {!isLoadingTaskHistory && taskHistory.length > 0 && jobTable()}
    </div>
  );
};

export default TaskHistory;
