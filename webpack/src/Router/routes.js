import React from 'react';
import OpenBoltTaskFormPage from '../Pages/OpenBoltTaskFormPage';
import OpenBoltTaskExecutionPage from '../Pages/OpenBoltTaskExecutionPage';
import TaskHistoryPage from '../Pages/TaskHistoryPage';

const routes = [
  {
    path: '/foreman_openbolt/new_task',
    exact: true,
    render: () => <OpenBoltTaskFormPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_openbolt'],
  },
  {
    path: '/foreman_openbolt/task_exec',
    exact: true,
    render: () => <OpenBoltTaskExecutionPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_openbolt'],
  },
  {
    path: '/foreman_openbolt/task_history',
    exact: true,
    render: () => <TaskHistoryPage />,
    requiresAuth: true,
    requiredPermissions: ['execute_openbolt'],
  },
];

export default routes;
