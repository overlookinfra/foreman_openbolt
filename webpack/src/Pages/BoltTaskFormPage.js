import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PageLayout from 'foremanReact/routes/common/PageLayout/PageLayout';
import BoltTaskForm from '../Components/BoltTaskForm';

const BoltTaskFormPage = () => (
  <PageLayout header={__('Run OpenBolt Task')}>
    <BoltTaskForm />
  </PageLayout>
);

export default BoltTaskFormPage;
