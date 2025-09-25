// Match the actual string coming from smart_proxy_openbolt
export const STATUS = {
  SUCCESS: 'success',
  FAILURE: 'failure',
  EXCEPTION: 'exception',
  INVALID: 'invalid',
  RUNNING: 'running',
  PENDING: 'pending',
};
export const COMPLETED_STATUSES = [
  STATUS.SUCCESS,
  STATUS.FAILURE,
  STATUS.EXCEPTION,
  STATUS.INVALID,
];
export const RUNNING_STATUSES = [STATUS.RUNNING, STATUS.PENDING];
export const ERROR_STATUSES = [
  STATUS.FAILURE,
  STATUS.EXCEPTION,
  STATUS.INVALID,
];
export const SUCCESS_STATUSES = [STATUS.SUCCESS];

export const POLLING_CONFIG = {
  INTERVAL: 5000, // 5 seconds
};

export const ENCRYPTED_DEFAULT_PLACEHOLDER = '[Use saved encrypted default]';

export const ROUTES = {
  PAGES: {
    LAUNCH_TASK: '/foreman_openbolt/page_launch_task',
    TASK_EXECUTION: '/foreman_openbolt/page_task_execution',
  },
  API: {
    RELOAD_TASKS: '/foreman_openbolt/reload_tasks',
    FETCH_TASKS: '/foreman_openbolt/fetch_tasks',
    FETCH_OPENBOLT_OPTIONS: '/foreman_openbolt/fetch_openbolt_options',
    LAUNCH_TASK: '/foreman_openbolt/launch_task',
    JOB_STATUS: '/foreman_openbolt/job_status',
    JOB_RESULT: '/foreman_openbolt/job_result',
    TASK_HISTORY: '/foreman_openbolt/fetch_task_history',
  },
};
