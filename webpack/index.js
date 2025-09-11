import componentRegistry from 'foremanReact/components/componentRegistry';

import LaunchTask from './src/Components/LaunchTask';
import OpenBoltTaskExecution from './src/Components/OpenBoltTaskExecution';

const components = [
  {
    name: 'LaunchTask',
    type: LaunchTask,
  },
  {
    name: 'OpenBoltTaskExecution',
    type: OpenBoltTaskExecution,
  },
];

components.forEach(component => {
  componentRegistry.register(component);
});
