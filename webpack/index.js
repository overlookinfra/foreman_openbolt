import componentRegistry from 'foremanReact/components/componentRegistry';

import LaunchTask from './src/Components/LaunchTask';
import TaskExecution from './src/Components/TaskExecution';

const components = [
  {
    name: 'LaunchTask',
    type: LaunchTask,
  },
  {
    name: 'TaskExecution',
    type: TaskExecution,
  },
];

components.forEach(component => {
  componentRegistry.register(component);
});
