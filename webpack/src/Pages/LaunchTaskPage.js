import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PageLayout from 'foremanReact/routes/common/PageLayout/PageLayout';
import LaunchTask from '../Components/LaunchTask';

const LaunchTaskPage = () => (
  <PageLayout header={__('Launch OpenBolt Task')}>
    <LaunchTask />
  </PageLayout>
);

export default LaunchTaskPage;
