import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PageLayout from 'foremanReact/routes/common/PageLayout/PageLayout';
import TaskExecution from '../Components/TaskExecution';

const TaskExecutionPage = () => (
  <PageLayout header={__('Task Execution')}>
    <TaskExecution />
  </PageLayout>
);

export default TaskExecutionPage;
