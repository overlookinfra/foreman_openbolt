import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PageLayout from 'foremanReact/routes/common/PageLayout/PageLayout';
import TaskJobs from '../Components/TaskJobs';

const TaskJobsPage = () => (
  <PageLayout header={__('Task History')}>
    <TaskJobs />
  </PageLayout>
);

export default TaskJobsPage;
