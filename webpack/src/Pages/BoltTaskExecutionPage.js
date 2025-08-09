import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PageLayout from 'foremanReact/routes/common/PageLayout/PageLayout';
import BoltTaskExecution from '../Components/BoltTaskExecution';

const BoltTaskExecutionPage = () => (
  <PageLayout header={__('Task Execution')}>
    <BoltTaskExecution />
  </PageLayout>
);

export default BoltTaskExecutionPage;
