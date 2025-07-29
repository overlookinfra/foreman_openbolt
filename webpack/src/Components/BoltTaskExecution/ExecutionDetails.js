import React from 'react';
import PropTypes from 'prop-types';
import { translate as __, sprintf } from 'foremanReact/common/I18n';
import {
  Card,
  CardBody,
  CardHeader,
  CardTitle,
  DescriptionList,
  DescriptionListGroup,
  DescriptionListTerm,
  DescriptionListDescription,
  Label,
  Flex,
  Spinner
} from '@patternfly/react-core';
import {
  CheckCircleIcon,
  ExclamationCircleIcon,
  InProgressIcon,
  ClockIcon,
  TimesCircleIcon
} from '@patternfly/react-icons';
import { STATUS, POLLING_CONFIG } from '../common/constants';

const STATUS_CONFIGS = {
  [STATUS.SUCCESS]: {
    icon: CheckCircleIcon,
    color: 'green',
    label: __('Success')
  },
  [STATUS.FAILURE]: {
    icon: ExclamationCircleIcon,
    color: 'red',
    label: __('Failed')
  },
  [STATUS.EXCEPTION]: {
    icon: ExclamationCircleIcon,
    color: 'red',
    label: __('Exception')
  },
  [STATUS.INVALID]: {
    icon: ExclamationCircleIcon,
    color: 'red',
    label: __('Invalid')
  },
  [STATUS.RUNNING]: {
    icon: InProgressIcon,
    color: 'blue',
    label: __('Running')
  },
  [STATUS.PENDING]: {
    icon: ClockIcon,
    color: 'blue',
    label: __('Pending')
  }
};

const getStatusConfig = (status) => {
  return STATUS_CONFIGS[status] || {
    icon: TimesCircleIcon,
    color: 'grey',
    label: __('Unknown')
  };
};

const DescriptionItem = ({ label, children }) => (
  <DescriptionListGroup>
    <DescriptionListTerm>{label}</DescriptionListTerm>
    <DescriptionListDescription>{children}</DescriptionListDescription>
  </DescriptionListGroup>
)

const StatusLabel = ({ status, isPolling }) => {
  const statusConfig = getStatusConfig(status);
  const StatusIcon = statusConfig.icon;
  const intervalSeconds = Math.round(POLLING_CONFIG.INTERVAL / 1000);

  return (
    <Flex spaceItems={{ default: 'spaceItemsSm' }} alignItems={{ default: 'alignItemsCenter' }}>
      <Label color={statusConfig.color} icon={<StatusIcon />}>
        {statusConfig.label}
      </Label>
      {isPolling && (
        <>
          <Spinner size="sm" aria-label="Polling" />
          <span className="pf-v5-u-color-200 pf-v5-u-font-size-sm">
            {sprintf(__('Updating every %s seconds...'), intervalSeconds)}
          </span>
        </>
      )}
    </Flex>
  );
};

const ExecutionDetails = ({ 
  proxyName, 
  jobId, 
  jobStatus, 
  pollCount, 
  isPolling 
}) => (
  <Card className="pf-v5-u-mb-md">
    <CardHeader>
      <CardTitle>{__('Execution Details')}</CardTitle>
    </CardHeader>
    <CardBody>
      <DescriptionList isHorizontal>
        <DescriptionItem label={__('Proxy')}>
          {proxyName || <em>{__('Unknown')}</em>}
        </DescriptionItem>

        <DescriptionItem label={__('Job ID')}>
          <code>{jobId}</code>
        </DescriptionItem>

        <DescriptionItem label={__('Status')}>
          <StatusLabel status={jobStatus} isPolling={isPolling} />
        </DescriptionItem>

        {pollCount > 0 && (
          <DescriptionItem label={__('Checks')}>
            {pollCount} {pollCount === 1 ? __('time') : __('times')}
          </DescriptionItem>
        )}
      </DescriptionList>
    </CardBody>
  </Card>
);

ExecutionDetails.propTypes = {
  proxyName: PropTypes.string,
  jobId: PropTypes.string.isRequired,
  jobStatus: PropTypes.string.isRequired,
  pollCount: PropTypes.number.isRequired,
  isPolling: PropTypes.bool.isRequired
};

ExecutionDetails.defaultProps = {
  proxyName: null
};

export default ExecutionDetails;
