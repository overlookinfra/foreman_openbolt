import React from 'react';
import PropTypes from 'prop-types';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import {
  Card,
  CardBody,
  Bullseye,
  EmptyState,
  EmptyStateVariant,
  EmptyStateHeader,
  EmptyStateIcon,
  EmptyStateBody,
  Spinner,
} from '@patternfly/react-core';
import { RUNNING_STATUSES } from '../common/constants';

const LoadingIndicator = ({ jobStatus }) => {
  const getMessage = () => {
    switch (jobStatus) {
      case RUNNING_STATUSES.includes(jobStatus):
        return sprintf(__('Task is %s...'), jobStatus);
      default:
        return __('Processing task results...');
    }
  };

  return (
    <Card className="pf-v5-u-mb-md">
      <CardBody>
        <Bullseye>
          <EmptyState variant={EmptyStateVariant.lg}>
            <EmptyStateHeader
              titleText={getMessage()}
              icon={<EmptyStateIcon icon={Spinner} />}
              headingLevel="h3"
            />
            <EmptyStateBody>
              {__(
                'This page will update automatically when the task completes.'
              )}
            </EmptyStateBody>
          </EmptyState>
        </Bullseye>
      </CardBody>
    </Card>
  );
};

LoadingIndicator.propTypes = {
  jobStatus: PropTypes.string.isRequired,
};

export default LoadingIndicator;
