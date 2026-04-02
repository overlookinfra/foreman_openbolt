import React, { useState } from 'react';
import PropTypes from 'prop-types';
import { translate as __ } from 'foremanReact/common/I18n';
import { Tab, TabTitleIcon, TabTitleText, Tabs } from '@patternfly/react-core';

import { MonitoringIcon, TaskIcon } from '@patternfly/react-icons';

import ExecutionDetails from './ExecutionDetails';
import TaskDetails from './TaskDetails';

const ExecutionDisplay = ({
  smartProxy,
  jobId,
  jobStatus,
  isPolling,
  targets,
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
          smartProxy={smartProxy}
          jobId={jobId}
          jobStatus={jobStatus}
          isPolling={isPolling}
          targets={targets}
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
  smartProxy: PropTypes.shape({
    id: PropTypes.number,
    name: PropTypes.string,
  }),
  jobId: PropTypes.string.isRequired,
  jobStatus: PropTypes.string.isRequired,
  isPolling: PropTypes.bool.isRequired,
  targets: PropTypes.arrayOf(PropTypes.string).isRequired,
  submittedAt: PropTypes.string,
  completedAt: PropTypes.string,
  taskName: PropTypes.string,
  taskDescription: PropTypes.string,
  taskParameters: PropTypes.object,
};

ExecutionDisplay.defaultProps = {
  smartProxy: null,
  submittedAt: null,
  completedAt: null,
  taskName: null,
  taskDescription: null,
  taskParameters: {},
};

export default ExecutionDisplay;
