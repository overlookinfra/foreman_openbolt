import React from 'react';
import BoltTaskFormPage from '../Pages/BoltTaskFormPage';
import BoltTaskExecutionPage from '../Pages/BoltTaskExecutionPage';
import TaskJobsPage from '../Pages/TaskJobsPage';

const routes = [
  {
    path: '/foreman_bolt/new_task',
    exact: true,
    render: () => <BoltTaskFormPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_bolt'],
  },
  {
    path: '/foreman_bolt/task_exec',
    exact: true,
    render: () => <BoltTaskExecutionPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_bolt'],
  },
  {
    path: '/foreman_bolt/task_jobs',
    exact: true,
    render: () => <TaskJobsPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_bolt'],
  },
];

export default routes;
