import React, { useState, useEffect } from 'react';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
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
  ArrowRightIcon,
  CheckCircleIcon,
  ExclamationCircleIcon,
  InfoCircleIcon,
  InProgressIcon,
  OutlinedClockIcon,
  UnknownIcon,
} from '@patternfly/react-icons';
import { ROUTES, STATUS } from '../common/constants';
import { useShowMessage, extractErrorMessage, formatDuration, formatDate } from '../common/helpers';
import HostsPopover from '../common/HostsPopover';
import TaskPopover from './TaskPopover';

const getStatusLabel = status => {
  const configs = {
    [STATUS.SUCCESS]: { color: 'green', icon: <CheckCircleIcon /> },
    [STATUS.FAILURE]: { color: 'red', icon: <ExclamationCircleIcon /> },
    [STATUS.EXCEPTION]: { color: 'orange', icon: <ExclamationCircleIcon /> },
    [STATUS.INVALID]: { color: 'yellow', icon: <ExclamationCircleIcon /> },
    [STATUS.RUNNING]: { color: 'blue', icon: <InProgressIcon /> },
    [STATUS.PENDING]: { color: 'blue', icon: <OutlinedClockIcon /> },
  };

  const config = configs[status] || { color: 'grey', icon: <UnknownIcon /> };
  return (
    <Label color={config.color} icon={config.icon}>
      {status}
    </Label>
  );
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
        const { data } = await API.get(
          `${ROUTES.API.TASK_HISTORY}?page=${page}&per_page=${perPage}`
        );

        if (!cancelled && data) {
          setTaskHistory(data.results || []);
          setTotal(data.total || 0);
        }
      } catch (error) {
        if (!cancelled) {
          showMessage(sprintf(__('Failed to load task history: %s'), extractErrorMessage(error)));
        }
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
      <Spinner size="xl" aria-label={__('Loading task history')} />
    </Bullseye>
  );

  const noJobs = () => (
    <EmptyState>
      <EmptyStateHeader
        titleText={__('No task history found')}
        icon={<EmptyStateIcon icon={InfoCircleIcon} />}
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
        aria-label={__('Task history table')}
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
            <Th modifier="wrap">{__('Submitted')}</Th>
            <Th modifier="wrap">{__('Completed')}</Th>
            <Th modifier="wrap">{__('Duration')}</Th>
            <Th modifier="wrap">{__('Details')}</Th>
          </Tr>
        </Thead>
        <Tbody>
          {taskHistory.map(job => (
            <Tr key={job.job_id}>
              <Td hasRightBorder>
                <TaskPopover
                  taskName={job.task_name}
                  taskDescription={job.task_description}
                  taskParameters={job.task_parameters}
                />
              </Td>
              <Td hasRightBorder>{getStatusLabel(job.status)}</Td>
              <Td hasRightBorder>
                <HostsPopover targets={job.targets || []} />
              </Td>
              <Td hasRightBorder>{formatDate(job.submitted_at)}</Td>
              <Td hasRightBorder>
                {job.completed_at ? formatDate(job.completed_at) : ''}
              </Td>
              <Td hasRightBorder>{formatDuration(job.duration)}</Td>
              <Td hasRightBorder>
                <a
                  href={`${ROUTES.PAGES.TASK_EXECUTION}?job_id=${job.job_id}`}
                  aria-label={__('View Details')}
                  title={__('View Details')}
                >
                  <ArrowRightIcon />
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
