// Match the actual string coming from smart_proxy_bolt
export const STATUS = {
  SUCCESS: 'success',
  FAILURE: 'failure',
  EXCEPTION: 'exception',
  INVALID: 'invalid',
  RUNNING: 'running',
  PENDING: 'pending'
};
export const COMPLETED_STATUSES = [STATUS.SUCCESS, STATUS.FAILURE, STATUS.EXCEPTION, STATUS.INVALID];
export const RUNNING_STATUSES = [STATUS.RUNNING, STATUS.PENDING];
export const ERROR_STATUSES = [STATUS.FAILURE, STATUS.EXCEPTION, STATUS.INVALID];
export const SUCCESS_STATUSES = [STATUS.SUCCESS];

export const POLLING_CONFIG = {
  INTERVAL: 5000, // 5 seconds
};

export const ROUTES = {
  PAGES: {
    NEW_TASK: '/foreman_bolt/new_task',
    TASK_EXECUTION: '/foreman_bolt/task_exec'
  },
  API: {
    RELOAD_TASKS: '/foreman_bolt/reload_tasks',
    FETCH_TASKS: '/foreman_bolt/fetch_tasks',
    FETCH_BOLT_OPTIONS: '/foreman_bolt/fetch_bolt_options',
    EXECUTE_TASK: '/foreman_bolt/execute_task',
    JOB_STATUS: '/foreman_bolt/job_status',
    JOB_RESULT: '/foreman_bolt/job_result',
  }
};
