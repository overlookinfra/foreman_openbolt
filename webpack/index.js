import componentRegistry from 'foremanReact/components/componentRegistry';

import BoltTaskForm from './src/Components/BoltTaskForm';
import BoltTaskExecution from './src/Components/BoltTaskExecution';

const components = [
  {
    name: 'BoltTaskForm',
    type: BoltTaskForm,
  },
  {
    name: 'BoltTaskExecution',
    type: BoltTaskExecution,
  },
];

components.forEach(component => {
  componentRegistry.register(component);
});
