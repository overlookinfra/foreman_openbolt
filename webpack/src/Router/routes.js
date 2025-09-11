import React from 'react';
import LaunchTaskPage from '../Pages/LaunchTaskPage';
import TaskExecutionPage from '../Pages/TaskExecutionPage';
import TaskHistoryPage from '../Pages/TaskHistoryPage';

const routes = [
  {
    path: '/foreman_openbolt/page_launch_task',
    exact: true,
    render: () => <LaunchTaskPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_openbolt'],
  },
  {
    path: '/foreman_openbolt/page_task_execution',
    exact: true,
    render: () => <TaskExecutionPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_openbolt'],
  },
  {
    path: '/foreman_openbolt/page_task_history',
    exact: true,
    render: () => <TaskHistoryPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_openbolt'],
  },
];

export default routes;
