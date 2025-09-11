import React from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import PageLayout from 'foremanReact/routes/common/PageLayout/PageLayout';
import OpenBoltTaskForm from '../Components/OpenBoltTaskForm';

const OpenBoltTaskFormPage = () => (
  <PageLayout header={__('Run OpenBolt Task')}>
    <OpenBoltTaskForm />
  </PageLayout>
);

export default OpenBoltTaskFormPage;
