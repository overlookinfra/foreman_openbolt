import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PageLayout from 'foremanReact/routes/common/PageLayout/PageLayout';
import OpenBoltTaskExecution from '../Components/OpenBoltTaskExecution';

const OpenBoltTaskExecutionPage = () => (
  <PageLayout header={__('Task Execution')}>
    <OpenBoltTaskExecution />
  </PageLayout>
);

export default OpenBoltTaskExecutionPage;
