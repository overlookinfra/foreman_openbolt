import componentRegistry from 'foremanReact/components/componentRegistry';

import OpenBoltTaskForm from './src/Components/OpenBoltTaskForm';
import OpenBoltTaskExecution from './src/Components/OpenBoltTaskExecution';

const components = [
  {
    name: 'OpenBoltTaskForm',
    type: OpenBoltTaskForm,
  },
  {
    name: 'OpenBoltTaskExecution',
    type: OpenBoltTaskExecution,
  },
];

components.forEach(component => {
  componentRegistry.register(component);
});
