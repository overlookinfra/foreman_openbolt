import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PageLayout from 'foremanReact/routes/common/PageLayout/PageLayout';
import TaskHistory from '../Components/TaskHistory';

const TaskHistoryPage = () => (
  <PageLayout header={__('Task History')}>
    <TaskHistory />
  </PageLayout>
);

export default TaskHistoryPage;
