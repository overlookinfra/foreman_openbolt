import React from 'react';
import PropTypes from 'prop-types';
import {
  EmptyState,
  EmptyStateIcon,
  EmptyStateHeader,
} from '@patternfly/react-core';
import { InfoCircleIcon } from '@patternfly/react-icons';

const EmptyContent = ({ title }) => (
  <EmptyState>
    <EmptyStateHeader
      titleText={title}
      icon={<EmptyStateIcon icon={InfoCircleIcon} />}
      headingLevel="h4"
    />
  </EmptyState>
);

EmptyContent.propTypes = {
  title: PropTypes.string.isRequired,
};

export default EmptyContent;
