import React from 'react';
import PropTypes from 'prop-types';
import { translate as __, sprintf } from 'foremanReact/common/I18n';
import {
  Card,
  CardBody,
  DescriptionList,
  DescriptionListGroup,
  DescriptionListTerm,
  DescriptionListDescription,
  Label,
  Flex,
  FlexItem,
  Text,
  TextVariants,
} from '@patternfly/react-core';
import {
  CheckCircleIcon,
  ExclamationCircleIcon,
  InProgressIcon,
  ClockIcon,
  TimesCircleIcon,
} from '@patternfly/react-icons';
import { STATUS, POLLING_CONFIG } from '../common/constants';

const STATUS_CONFIGS = {
  [STATUS.SUCCESS]: {
    icon: CheckCircleIcon,
    color: 'green',
    label: __('Success'),
  },
  [STATUS.FAILURE]: {
    icon: ExclamationCircleIcon,
    color: 'red',
    label: __('Failed'),
  },
  [STATUS.EXCEPTION]: {
    icon: ExclamationCircleIcon,
    color: 'red',
    label: __('Exception'),
  },
  [STATUS.INVALID]: {
    icon: ExclamationCircleIcon,
    color: 'red',
    label: __('Invalid'),
  },
  [STATUS.RUNNING]: {
    icon: InProgressIcon,
    color: 'blue',
    label: __('Running'),
  },
  [STATUS.PENDING]: {
    icon: ClockIcon,
    color: 'blue',
    label: __('Pending'),
  },
};

const getStatusConfig = status =>
  STATUS_CONFIGS[status] || {
    icon: TimesCircleIcon,
    color: 'grey',
    label: __('Unknown'),
  };

const formatExecutionTime = (submittedAt, completedAt) => {
  if (!submittedAt) return __('-');

  const start = new Date(submittedAt);
  const end = completedAt ? new Date(completedAt) : new Date();
  const totalSeconds = Math.floor((end - start) / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const parts = [];
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0 || hours > 0) parts.push(`${minutes}m`);
  parts.push(`${seconds}s`);

  return parts.join('');
};

const DescriptionItem = ({ label, children }) => (
  <DescriptionListGroup>
    <DescriptionListTerm>{label}</DescriptionListTerm>
    <DescriptionListDescription>{children}</DescriptionListDescription>
  </DescriptionListGroup>
);

DescriptionItem.propTypes = {
  label: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired,
};

const StatusLabel = ({ status, isPolling }) => {
  const statusConfig = getStatusConfig(status);
  const StatusIcon = statusConfig.icon;
  const intervalSeconds = Math.round(POLLING_CONFIG.INTERVAL / 1000);

  return (
    <Flex
      spaceItems={{ default: 'spaceItemsSm' }}
      alignItems={{ default: 'alignItemsCenter' }}
    >
      <FlexItem>
        <Label color={statusConfig.color} icon={<StatusIcon />}>
          {statusConfig.label}
        </Label>
      </FlexItem>
      {isPolling && (
        <>
          <FlexItem>
            <Text component={TextVariants.small} className="pf-v5-u-color-200">
              {sprintf(__('Updating every %s seconds...'), intervalSeconds)}
            </Text>
          </FlexItem>
        </>
      )}
    </Flex>
  );
};

StatusLabel.propTypes = {
  status: PropTypes.string.isRequired,
  isPolling: PropTypes.bool.isRequired,
};

const ExecutionDetails = ({
  proxyId,
  proxyName,
  jobId,
  jobStatus,
  isPolling,
  targetCount,
  submittedAt,
  completedAt,
}) => (
  <Card>
    <CardBody>
      <DescriptionList isHorizontal>
        <DescriptionItem label={__('Proxy')}>
          {proxyId && proxyName ? (
            <a href={`/smart_proxies/${proxyId}`}>{proxyName}</a>
          ) : (
            <em>{__('Unknown')}</em>
          )}
        </DescriptionItem>

        <DescriptionItem label={__('Job ID')}>
          <code>{jobId}</code>
        </DescriptionItem>

        {targetCount && (
          <DescriptionItem label={__('Host Count')}>
            {targetCount} {targetCount === 1 ? __('host') : __('hosts')}
          </DescriptionItem>
        )}

        <DescriptionItem label={__('Status')}>
          <StatusLabel status={jobStatus} isPolling={isPolling} />
        </DescriptionItem>

        <DescriptionItem label={__('Execution Time')}>
          {formatExecutionTime(submittedAt, completedAt)}
        </DescriptionItem>
      </DescriptionList>
    </CardBody>
  </Card>
);

ExecutionDetails.propTypes = {
  proxyId: PropTypes.string.isRequired,
  proxyName: PropTypes.string.isRequired,
  jobId: PropTypes.string.isRequired,
  jobStatus: PropTypes.string.isRequired,
  isPolling: PropTypes.bool.isRequired,
  targetCount: PropTypes.oneOfType([PropTypes.number, PropTypes.string])
    .isRequired,
  submittedAt: PropTypes.string,
  completedAt: PropTypes.string,
};

ExecutionDetails.defaultProps = {
  submittedAt: null,
  completedAt: null,
};

export default ExecutionDetails;
