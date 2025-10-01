import React, { useState } from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { Tab, TabTitleIcon, TabTitleText, Tabs } from '@patternfly/react-core';

import { MonitoringIcon, TaskIcon } from '@patternfly/react-icons';

import ExecutionDetails from './ExecutionDetails';
import TaskDetails from './TaskDetails';

const ExecutionDisplay = ({
  proxyName,
  jobId,
  jobStatus,
  pollCount,
  isPolling,
  targetCount,
  submittedAt,
  completedAt,
  taskName,
  taskDescription,
  taskParameters,
}) => {
  const [activeTabKey, setActiveTabKey] = useState(0);

  return (
    <Tabs
      activeKey={activeTabKey}
      onSelect={(_event, tabIndex) => setActiveTabKey(tabIndex)}
    >
      <Tab
        eventKey={0}
        title={
          <>
            <TabTitleIcon>
              <MonitoringIcon />
            </TabTitleIcon>
            <TabTitleText>{__('Execution Details')}</TabTitleText>
          </>
        }
      >
        <ExecutionDetails
          proxyName={proxyName}
          jobId={jobId}
          jobStatus={jobStatus}
          pollCount={pollCount}
          isPolling={isPolling}
          targetCount={targetCount}
          submittedAt={submittedAt}
          completedAt={completedAt}
        />
      </Tab>

      <Tab
        eventKey={1}
        title={
          <>
            <TabTitleIcon>
              <TaskIcon />
            </TabTitleIcon>
            <TabTitleText>{__('Task Details')}</TabTitleText>
          </>
        }
      >
        <TaskDetails
          taskName={taskName}
          taskDescription={taskDescription}
          taskParameters={taskParameters}
        />
      </Tab>
    </Tabs>
  );
};

ExecutionDisplay.propTypes = {
  proxyName: PropTypes.string.isRequired,
  jobId: PropTypes.string.isRequired,
  jobStatus: PropTypes.string.isRequired,
  pollCount: PropTypes.number.isRequired,
  isPolling: PropTypes.bool.isRequired,
  targetCount: PropTypes.oneOfType([PropTypes.number, PropTypes.string])
    .isRequired,
  submittedAt: PropTypes.string,
  completedAt: PropTypes.string,
  taskName: PropTypes.string.isRequired,
  taskDescription: PropTypes.string,
  taskParameters: PropTypes.object,
};

ExecutionDisplay.defaultProps = {
  submittedAt: null,
  completedAt: null,
  taskDescription: null,
  taskParameters: {},
};

export default ExecutionDisplay;
